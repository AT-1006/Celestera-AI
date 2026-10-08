import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

enum BiometricType { fingerprint, face, none }

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device supports biometrics at all
  Future<bool> isDeviceSupported() async {
    return await _auth.isDeviceSupported();
  }

  /// Check if biometrics are enrolled (e.g. fingerprint/face set up by user)
  Future<bool> canAuthenticate() async {
    final bool isSupported = await _auth.isDeviceSupported();
    if (!isSupported) return false;
    return await _auth.canCheckBiometrics;
  }

  /// Returns which biometric types are available on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    final List<BiometricType> result = [];

    try {
      final List<BiometricType> available =
          (await _auth.getAvailableBiometrics())
              .map((b) {
                switch (b) {
                  case BiometricType.fingerprint:
                    return BiometricType.fingerprint;
                  case BiometricType.face:
                    return BiometricType.face;
                  default:
                    return BiometricType.none;
                }
              })
              .where((b) => b != BiometricType.none)
              .toList();

      result.addAll(available);
    } on PlatformException {
      // Device doesn't support biometrics or error reading them
    }

    return result;
  }

  /// Returns a user-friendly label like "Face ID" or "Fingerprint"
  Future<String> getBiometricLabel() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) return 'Face ID';
    if (biometrics.contains(BiometricType.fingerprint)) return 'Fingerprint';
    return 'Biometric';
  }

  /// Perform biometric authentication
  /// Returns [AuthResult] with success/failure and reason
  Future<AuthResult> authenticate({
    String reason = 'Please authenticate to continue',
  }) async {
    try {
      final bool canAuth = await canAuthenticate();
      if (!canAuth) {
        return AuthResult(
          success: false,
          error: AuthError.notAvailable,
          message: 'Biometrics not available on this device.',
        );
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,       // keeps auth prompt if app is backgrounded
          biometricOnly: true,    // no device PIN fallback from biometric prompt
          sensitiveTransaction: true,
        ),
      );

      return AuthResult(
        success: didAuthenticate,
        error: didAuthenticate ? null : AuthError.failed,
        message: didAuthenticate ? 'Authenticated successfully' : 'Authentication failed',
      );
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    }
  }

  AuthResult _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case auth_error.notEnrolled:
        return AuthResult(
          success: false,
          error: AuthError.notEnrolled,
          message: 'No biometrics enrolled. Please set up fingerprint or Face ID in device settings.',
        );
      case auth_error.lockedOut:
        return AuthResult(
          success: false,
          error: AuthError.lockedOut,
          message: 'Too many failed attempts. Try again in 30 seconds.',
        );
      case auth_error.permanentlyLockedOut:
        return AuthResult(
          success: false,
          error: AuthError.permanentlyLockedOut,
          message: 'Biometrics locked. Please use your device PIN to unlock.',
        );
      case auth_error.notAvailable:
        return AuthResult(
          success: false,
          error: AuthError.notAvailable,
          message: 'Biometric authentication is not available.',
        );
      default:
        return AuthResult(
          success: false,
          error: AuthError.unknown,
          message: 'An error occurred: ${e.message}',
        );
    }
  }
}

enum AuthError {
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  failed,
  unknown,
}

class AuthResult {
  final bool success;
  final AuthError? error;
  final String message;

  const AuthResult({
    required this.success,
    this.error,
    required this.message,
  });
}
