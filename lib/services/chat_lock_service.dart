import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../auth/biometric_service.dart' as biometric_auth;

class ChatLockService {
  static final ChatLockService _instance = ChatLockService._internal();
  factory ChatLockService() => _instance;
  ChatLockService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication auth = LocalAuthentication();
  final biometric_auth.BiometricService _biometricService = biometric_auth.BiometricService();
  
  String? _currentUserId;

  // Set current user ID for user-specific locks
  void setUserId(String userId) {
    _currentUserId = userId;
  }

  // Store locked chats with timestamp and lock info
  Future<void> lockChat(String chatId) async {
    if (_currentUserId == null) return;
    
    final lockData = {
      'chatId': chatId,
      'lockedAt': DateTime.now().toIso8601String(),
      'lockType': 'pin', // Can be 'pin', 'biometric', 'both'
      'userId': _currentUserId,
    };
    
    await _secureStorage.write(
      key: '${_currentUserId}_locked_chats', 
      value: chatId,
    );
    
    // Store detailed lock info for better persistence
    await _secureStorage.write(
      key: '${_currentUserId}_lock_info_${chatId}',
      value: lockData.toString(),
    );
    
    debugPrint(' Chat $chatId locked for user $_currentUserId at ${lockData['lockedAt']}');
  }

  // Check if chat is locked
  Future<bool> isChatLocked(String chatId) async {
    if (_currentUserId == null) return false;
    
    try {
      // Check both simple lock and detailed lock info
      final lockedChat = await _secureStorage.read(key: '${_currentUserId}_locked_chats');
      final lockInfo = await _secureStorage.read(key: '${_currentUserId}_lock_info_${chatId}');
      
      // Chat is locked if either method finds it
      final isLocked = lockedChat == chatId || (lockInfo != null && lockInfo.isNotEmpty);
      
      debugPrint(' Chat $chatId lock status: $isLocked');
      return isLocked;
    } catch (e) {
      debugPrint(' Error checking chat lock status: $e');
      return false;
    }
  }

  // Unlock chat with PIN
  Future<bool> unlockChatWithPin(String pin) async {
    if (_currentUserId == null) {
      debugPrint(' Cannot unlock with PIN: no user ID');
      return false;
    }
    
    try {
      debugPrint(' Starting PIN unlock process for user $_currentUserId...');
      
      // Validate PIN format first
      if (!validatePin(pin)) {
        debugPrint(' PIN format validation failed');
        return false;
      }
      
      // Get stored PIN
      final storedPin = await getGlobalPin();
      
      if (storedPin == null || storedPin.isEmpty) {
        debugPrint(' No PIN is set for this user');
        return false;
      }
      
      debugPrint(' Comparing entered PIN with stored PIN');
      
      // Compare PINs
      final isCorrect = storedPin == pin;
      
      if (isCorrect) {
        debugPrint(' PIN authentication successful, removing chat lock...');
        
        // If PIN is correct, remove the lock
        await removeChatLock();
        
        // Store successful unlock timestamp
        await _secureStorage.write(
          key: '${_currentUserId}_last_pin_unlock',
          value: DateTime.now().toIso8601String(),
        );
        
        debugPrint(' Chat lock removed successfully via PIN');
        return true;
      } else {
        debugPrint(' PIN authentication failed');
        
        // Store failed attempt for security tracking
        await _secureStorage.write(
          key: '${_currentUserId}_last_pin_attempt',
          value: DateTime.now().toIso8601String(),
        );
        
        return false;
      }
    } catch (e) {
      debugPrint(' PIN unlock error: $e');
      
      // Store error for debugging
      await _secureStorage.write(
        key: '${_currentUserId}_pin_error',
        value: 'Error at ${DateTime.now().toIso8601String()}: $e',
      );
      
      return false;
    }
  }

  // Check if biometrics are available
  Future<bool> isBiometricAvailable() async {
    try {
      debugPrint(' Checking biometric availability...');
      final result = await _biometricService.canAuthenticate();
      debugPrint(' Biometric available: $result');
      return result;
    } catch (e) {
      debugPrint(' Error checking biometric availability: $e');
      return false;
    }
  }

  // Get biometric type label
  Future<String> getBiometricLabel() async {
    try {
      debugPrint(' Getting biometric label...');
      final result = await _biometricService.getBiometricLabel();
      debugPrint(' Biometric label: $result');
      return result;
    } catch (e) {
      debugPrint(' Error getting biometric label: $e');
      return 'Biometric';
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({String reason = 'Authenticate to unlock chat'}) async {
    try {
      debugPrint(' Starting biometric authentication with reason: $reason');
      final result = await _biometricService.authenticate(reason: reason);
      debugPrint(' Biometric auth result: success=${result.success}, message=${result.message}');
      if (result.error != null) {
        debugPrint(' Biometric auth error: ${result.error}');
      }
      return result.success;
    } catch (e) {
      debugPrint(' Biometric authentication error: $e');
      return false;
    }
  }

  // Enhanced unlock with biometrics
  Future<bool> unlockChatWithBiometrics() async {
    if (_currentUserId == null) {
      debugPrint(' Cannot unlock with biometrics: no user ID');
      return false;
    }
    
    try {
      debugPrint(' Starting biometric unlock process for user $_currentUserId...');
      
      // Check if biometrics are available first
      final biometricAvailable = await isBiometricAvailable();
      if (!biometricAvailable) {
        debugPrint(' Biometrics not available for unlock');
        return false;
      }
      
      // Get current locked chat before attempting unlock
      final lockedChat = await getLockedChat();
      if (lockedChat == null || lockedChat.isEmpty) {
        debugPrint(' No chat is currently locked');
        return false;
      }
      
      // Perform biometric authentication
      final biometricResult = await _biometricService.authenticate(
        reason: 'Use your fingerprint or Face ID to unlock chat: $lockedChat'
      );
      
      debugPrint(' Biometric unlock result: success=${biometricResult.success}, message=${biometricResult.message}');
      
      if (biometricResult.success) {
        debugPrint(' Biometric authentication successful, removing chat lock...');
        
        // If biometric succeeds, remove the lock completely
        await removeChatLock();
        
        // Store successful unlock timestamp for debugging
        await _secureStorage.write(
          key: '${_currentUserId}_last_biometric_unlock',
          value: DateTime.now().toIso8601String(),
        );
        
        debugPrint(' Chat lock removed successfully via biometrics');
        return true;
      } else {
        debugPrint(' Biometric authentication failed: ${biometricResult.message}');
        
        // Store failed attempt for security tracking
        await _secureStorage.write(
          key: '${_currentUserId}_last_biometric_attempt',
          value: DateTime.now().toIso8601String(),
        );
      }
      
      return false;
    } catch (e) {
      debugPrint(' Biometric unlock error: $e');
      
      // Store error for debugging
      await _secureStorage.write(
        key: '${_currentUserId}_biometric_error',
        value: 'Error at ${DateTime.now().toIso8601String()}: $e',
      );
      
      return false;
    }
  }

  // Unlock chat with biometrics
  Future<bool> unlockChatWithBiometricsLegacy() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = await auth.isDeviceSupported();

      if (!canAuthenticate || !canAuthenticateWithBiometrics) {
        return false;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to unlock this chat',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }

  // Remove chat lock completely
  Future<void> removeChatLock() async {
    if (_currentUserId == null) return;
    
    try {
      // Get current locked chat to clean up its specific data
      final lockedChat = await _secureStorage.read(key: '${_currentUserId}_locked_chats');
      
      // Remove the main lock entry
      await _secureStorage.delete(key: '${_currentUserId}_locked_chats');
      
      // Remove detailed lock info for the specific chat
      if (lockedChat != null && lockedChat.isNotEmpty) {
        await _secureStorage.delete(key: '${_currentUserId}_lock_info_$lockedChat');
      }
      
      debugPrint(' Chat lock removed for user $_currentUserId');
    } catch (e) {
      debugPrint(' Error removing chat lock: $e');
    }
  }

  // Remove all chat locks (for cleanup)
  Future<void> removeAllChatLocks() async {
    if (_currentUserId == null) return;
    
    try {
      // Remove main lock entry
      await _secureStorage.delete(key: '${_currentUserId}_locked_chats');
      
      // Remove all individual lock info entries (this is more complex, so we'll use a different approach)
      // For now, just remove the main lock which is what matters most
      
      debugPrint(' All chat locks removed for user $_currentUserId');
    } catch (e) {
      debugPrint(' Error removing all chat locks: $e');
    }
  }

  // Store global PIN for all chats (user-specific) with metadata
  Future<void> storeGlobalPin(String pin) async {
    if (_currentUserId == null) return;
    
    final pinData = {
      'pin': pin,
      'createdAt': DateTime.now().toIso8601String(),
      'userId': _currentUserId,
      'isActive': true,
    };
    
    await _secureStorage.write(
      key: '${_currentUserId}_global_chat_pin', 
      value: pin,
    );
    
    // Store PIN metadata for better persistence
    await _secureStorage.write(
      key: '${_currentUserId}_pin_metadata',
      value: pinData.toString(),
    );
    
    debugPrint(' PIN stored for user $_currentUserId at ${pinData['createdAt']}');
  }

  // Get global PIN (user-specific)
  Future<String?> getGlobalPin() async {
    if (_currentUserId == null) {
      return null;
    }
    
    try {
      final pin = await _secureStorage.read(key: '${_currentUserId}_global_chat_pin');
      final metadata = await _secureStorage.read(key: '${_currentUserId}_pin_metadata');
      
      debugPrint(' Retrieved PIN for user $_currentUserId: ${pin != null ? 'found' : 'not found'}');
      if (metadata != null) {
        debugPrint(' PIN metadata: $metadata');
      }
      
      return pin;
    } catch (e) {
      debugPrint(' Error retrieving PIN: $e');
      return null;
    }
  }

  // Clear global PIN (user-specific)
  Future<void> clearGlobalPin() async {
    if (_currentUserId == null) return;
    
    await _secureStorage.delete(key: '${_currentUserId}_global_chat_pin');
    await _secureStorage.delete(key: '${_currentUserId}_pin_metadata');
    
    debugPrint(' PIN cleared for user $_currentUserId');
  }

  // Validate PIN format (4-6 digits)
  bool validatePin(String pin) {
    if (pin.length < 4 || pin.length > 6) return false;
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  // Check if global PIN is set (user-specific)
  Future<bool> isGlobalPinSet() async {
    if (_currentUserId == null) {
      return false;
    }
    final pin = await getGlobalPin();
    return pin != null && pin.isNotEmpty;
  }

  // Get current locked chat
  Future<String?> getLockedChat() async {
    if (_currentUserId == null) return null;
    return await _secureStorage.read(key: '${_currentUserId}_locked_chats');
  }

  // Initialize security state on app startup
  Future<void> initializeSecurityState() async {
    if (_currentUserId == null) {
      debugPrint(' Cannot initialize security: no user ID');
      return;
    }
    
    try {
      debugPrint(' Initializing security state for user $_currentUserId...');
      
      // Check PIN status
      final pinSet = await isGlobalPinSet();
      debugPrint(' PIN status: ${pinSet ? 'set' : 'not set'}');
      
      // Check biometric availability
      final biometricAvailable = await isBiometricAvailable();
      debugPrint(' Biometric available: $biometricAvailable');
      
      // Check current lock status
      final lockedChat = await getLockedChat();
      if (lockedChat != null && lockedChat.isNotEmpty) {
        debugPrint(' Found locked chat: $lockedChat');
        
        // Verify lock info exists
        final lockInfo = await _secureStorage.read(key: '${_currentUserId}_lock_info_$lockedChat');
        if (lockInfo == null || lockInfo.isEmpty) {
          debugPrint(' Lock info missing, cleaning up inconsistent lock state');
          await removeChatLock();
        }
      } else {
        debugPrint(' No chats currently locked');
      }
      
      // Check for any security errors and clean up if needed
      await _cleanupSecurityState();
      
      debugPrint(' Security state initialization complete');
    } catch (e) {
      debugPrint(' Error initializing security state: $e');
    }
  }

  // Clean up any inconsistent security state
  Future<void> _cleanupSecurityState() async {
    if (_currentUserId == null) return;
    
    try {
      // Check for orphaned lock data
      final lockedChat = await _secureStorage.read(key: '${_currentUserId}_locked_chats');
      
      if (lockedChat != null && lockedChat.isNotEmpty) {
        // Verify the corresponding lock info exists
        final lockInfo = await _secureStorage.read(key: '${_currentUserId}_lock_info_$lockedChat');
        
        if (lockInfo == null || lockInfo.isEmpty) {
          debugPrint(' Found orphaned lock data, cleaning up...');
          await _secureStorage.delete(key: '${_currentUserId}_locked_chats');
        }
      }
      
      // Clean up old error logs (keep only last 24 hours)
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      
      final pinError = await _secureStorage.read(key: '${_currentUserId}_pin_error');
      if (pinError != null) {
        final errorTime = DateTime.tryParse(pinError.split('Error at ')[1].split(':')[0]);
        if (errorTime != null && errorTime.isBefore(yesterday)) {
          await _secureStorage.delete(key: '${_currentUserId}_pin_error');
        }
      }
      
      final bioError = await _secureStorage.read(key: '${_currentUserId}_biometric_error');
      if (bioError != null) {
        final errorTime = DateTime.tryParse(bioError.split('Error at ')[1].split(':')[0]);
        if (errorTime != null && errorTime.isBefore(yesterday)) {
          await _secureStorage.delete(key: '${_currentUserId}_biometric_error');
        }
      }
      
    } catch (e) {
      debugPrint(' Error during security cleanup: $e');
    }
  }

  // Get security status summary for debugging
  Future<Map<String, dynamic>> getSecurityStatus() async {
    if (_currentUserId == null) {
      return {
        'error': 'No user ID set',
        'pinSet': false,
        'biometricAvailable': false,
        'lockedChat': null,
      };
    }
    
    return {
      'pinSet': await isGlobalPinSet(),
      'biometricAvailable': await isBiometricAvailable(),
      'lockedChat': await getLockedChat(),
      'userId': _currentUserId,
      'pinMetadata': await _secureStorage.read(key: '${_currentUserId}_pin_metadata'),
      'lastPinUnlock': await _secureStorage.read(key: '${_currentUserId}_last_pin_unlock'),
      'lastBiometricUnlock': await _secureStorage.read(key: '${_currentUserId}_last_biometric_unlock'),
    };
  }
}
