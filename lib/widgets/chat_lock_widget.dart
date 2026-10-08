import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/chat_lock_service.dart';

class ChatLockWidget extends StatefulWidget {
  final String chatId;
  final VoidCallback onUnlocked;
  final VoidCallback onCancelled;

  const ChatLockWidget({
    super.key,
    required this.chatId,
    required this.onUnlocked,
    required this.onCancelled,
  });

  @override
  State<ChatLockWidget> createState() => _ChatLockWidgetState();
}

class _ChatLockWidgetState extends State<ChatLockWidget> {
  final TextEditingController _pinController = TextEditingController();
  final ChatLockService _lockService = ChatLockService();
  bool _useBiometric = false;
  bool _isBiometricAvailable = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _lockService.isBiometricAvailable();
    
    setState(() {
      _isBiometricAvailable = isAvailable;
      _useBiometric = _isBiometricAvailable;
    });
  }

  Future<void> _authenticateWithPin() async {
    final pin = _pinController.text.trim();
    
    if (!_lockService.validatePin(pin)) {
      _showError('PIN must be 4-6 digits');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isUnlocked = await _lockService.unlockChatWithPin(pin);
      
      if (isUnlocked) {
        widget.onUnlocked();
      } else {
        _showError('Incorrect PIN');
      }
    } catch (e) {
      _showError('Authentication failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_isBiometricAvailable) return;

    setState(() => _isLoading = true);

    try {
      final isAuthenticated = await _lockService.unlockChatWithBiometrics();
      
      if (isAuthenticated) {
        widget.onUnlocked();
      } else {
        _showError('Biometric authentication failed');
      }
    } catch (e) {
      _showError('Biometric authentication failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock Icon
            Icon(
              Icons.lock,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              'Chat Locked',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'This chat is protected. Enter your PIN or use biometric authentication.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            
            // PIN Input
            if (!_useBiometric) ...[
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  hintText: '••••',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                ),
                onSubmitted: (_) => _authenticateWithPin(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Biometric Button
            if (_isBiometricAvailable && !_useBiometric)
              OutlinedButton.icon(
                onPressed: _authenticateWithBiometrics,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use Biometric'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            
            // PIN Input Button
            if (_useBiometric)
              OutlinedButton.icon(
                onPressed: () => setState(() => _useBiometric = false),
                icon: const Icon(Icons.pin),
                label: const Text('Use PIN'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            if (!_useBiometric) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : widget.onCancelled,
                      child: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _authenticateWithPin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }
}
