import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminBiometricService {
  static final AdminBiometricService _instance =
      AdminBiometricService._internal();
  factory AdminBiometricService() => _instance;
  AdminBiometricService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _keyEmail = 'admin_biometric_email';
  static const String _keyPassword = 'admin_biometric_password';
  static const String _keyEnabled = 'admin_biometric_enabled';

  Future<void> enableBiometrics() async {
    try {
      await _storage.write(key: _keyEnabled, value: 'true');
    } catch (e) {
      debugPrint("enableAdminBiometrics error: $e");
    }
  }

  Future<void> disableBiometrics() async {
    try {
      await _storage.write(key: _keyEnabled, value: 'false');
    } catch (e) {
      debugPrint("disableAdminBiometrics error: $e");
    }
  }

  Future<void> saveCredentials(String email, String password) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
      await enableBiometrics();
    } catch (e) {
      debugPrint("saveAdminCredentials error: $e");
    }
  }

  Future<Map<String, String>?> getCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint("getAdminCredentials error: $e");
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
      debugPrint("clearAdminCredentials error: $e");
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _keyEnabled);
      return enabled == 'true';
    } catch (e) {
      debugPrint("isAdminBiometricEnabled error: $e");
      return false;
    }
  }
}
