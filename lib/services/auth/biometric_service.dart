import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _keyEmail = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
  static const String _keyEnabled = 'biometric_enabled';

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      if (!await isBiometricAvailable()) {
        return const [];
      }
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint("getAvailableBiometrics error: $e");
      return const [];
    }
  }

  Future<String> getBiometricLabel() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    }
    if (biometrics.contains(BiometricType.fingerprint) ||
        biometrics.contains(BiometricType.strong) ||
        biometrics.contains(BiometricType.weak)) {
      return 'Fingerprint';
    }
    return 'Biometrics';
  }

  Future<bool> authenticate() async {
    return authenticateWithDeviceSecurity();
  }

  Future<bool> authenticateWithDeviceSecurity({
    bool biometricOnly = false,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to log in',
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint("Biometric Authentication Error: $e");
      return false;
    }
  }

  Future<void> enableBiometrics() async {
    try {
      await _storage.write(key: _keyEnabled, value: 'true');
    } catch (e) {
      debugPrint("enableBiometrics error: $e");
    }
  }

  Future<void> disableBiometrics() async {
    try {
      await _storage.write(key: _keyEnabled, value: 'false');
    } catch (e) {
      debugPrint("disableBiometrics error: $e");
    }
  }

  Future<void> saveCredentials(String email, String password) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
      await enableBiometrics();
    } catch (e) {
      debugPrint("saveCredentials error: $e");
    }
  }

  Future<Map<String, String>?> getCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      if (email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint("getCredentials error: $e");
    }
    return null;
  }

  Future<bool> hasStoredCredentials() async {
    final credentials = await getCredentials();
    return credentials != null;
  }

  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPassword);
      await disableBiometrics();
    } catch (e) {
      debugPrint("clearCredentials error: $e");
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _keyEnabled);
      return enabled == 'true';
    } catch (e) {
      debugPrint("isBiometricEnabled error: $e");
      return false;
    }
  }

  Future<void> clearStoredCredentialsOnly() async {
    try {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPassword);
    } catch (e) {
      debugPrint("clearStoredCredentialsOnly error: $e");
    }
  }
}
