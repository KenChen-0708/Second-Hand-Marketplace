import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../services/auth/admin_biometric_service.dart';

class AdminSecurityState extends ChangeNotifier {
  AdminSecurityState({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'admin.biometric.enabled';
  static const String _adminEmailKey = 'admin.biometric.email';
  static const Duration _sessionTimeout = Duration(minutes: 10);

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;
  final AdminBiometricService _biometricService = AdminBiometricService();

  Timer? _sessionTimer;
  bool _isInitialized = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isAdminSessionActive = false;
  bool _isSessionLocked = false;
  bool _hasStoredBiometricCredentials = false;
  String? _rememberedAdminEmail;
  String? _statusMessage;
  String? _lastAdminEmail;
  String? _lastAdminPassword;
  DateTime? _lastActivityAt;

  bool get isInitialized => _isInitialized;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAdminSessionActive => _isAdminSessionActive;
  bool get isSessionLocked => _isSessionLocked;
  bool get hasStoredBiometricCredentials => _hasStoredBiometricCredentials;
  String? get rememberedAdminEmail => _rememberedAdminEmail;
  String? get statusMessage => _statusMessage;
  bool get canUseBiometricUnlock =>
      _isBiometricAvailable &&
      _isBiometricEnabled &&
      _hasStoredBiometricCredentials &&
      (_rememberedAdminEmail?.isNotEmpty ?? false);

  Future<void> initialize() async {
    if (_isInitialized) {
      await refreshBiometricAvailability();
      await _syncStoredAdminBiometricState();
      return;
    }

    _isBiometricEnabled =
        await _secureStorage.read(key: _biometricEnabledKey) == 'true';
    _rememberedAdminEmail = await _secureStorage.read(key: _adminEmailKey);
    await _syncStoredAdminBiometricState();
    await refreshBiometricAvailability();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _syncStoredAdminBiometricState() async {
    _hasStoredBiometricCredentials =
        await _biometricService.hasStoredCredentials();
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    _isBiometricEnabled = _isBiometricEnabled || biometricEnabled;
    final credentials = await _biometricService.getCredentials();
    if ((_rememberedAdminEmail?.isEmpty ?? true) &&
        credentials?['email']?.isNotEmpty == true) {
      _rememberedAdminEmail = credentials!['email'];
    }
  }

  Future<void> refreshBiometricAvailability() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();
      _isBiometricAvailable =
          supported && canCheck && biometrics.isNotEmpty;
    } catch (_) {
      _isBiometricAvailable = false;
    }
    notifyListeners();
  }

  Future<bool> authenticateWithBiometrics({
    required String reason,
  }) async {
    await refreshBiometricAvailability();
    if (!_isBiometricAvailable) {
      _statusMessage =
          'Fingerprint or face recognition is not available on this device.';
      notifyListeners();
      return false;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      if (!authenticated) {
        _statusMessage = 'Biometric verification was cancelled.';
        notifyListeners();
      }

      return authenticated;
    } catch (e) {
      _statusMessage =
          'Biometric verification is unavailable on this device.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setBiometricPreference({
    required bool enabled,
  }) async {
    if (enabled) {
      if ((_lastAdminEmail?.isEmpty ?? true) ||
          (_lastAdminPassword?.isEmpty ?? true)) {
        _statusMessage =
            'Please sign in with your admin password once before enabling biometric login.';
        notifyListeners();
        return false;
      }

      final authenticated = await authenticateWithBiometrics(
        reason: 'Verify your identity to enable admin biometric login.',
      );
      if (!authenticated) {
        return false;
      }

      await _biometricService.saveCredentials(
        _lastAdminEmail!,
        _lastAdminPassword!,
      );
      _isBiometricEnabled = true;
      _hasStoredBiometricCredentials = true;
      _rememberedAdminEmail = _lastAdminEmail;
      await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
      if (_rememberedAdminEmail != null && _rememberedAdminEmail!.isNotEmpty) {
        await _secureStorage.write(
          key: _adminEmailKey,
          value: _rememberedAdminEmail,
        );
      }
      _statusMessage = 'Biometric login enabled for this admin account.';
    } else {
      await _biometricService.clearCredentials();
      _isBiometricEnabled = false;
      _hasStoredBiometricCredentials = false;
      _rememberedAdminEmail = null;
      await _secureStorage.delete(key: _biometricEnabledKey);
      await _secureStorage.delete(key: _adminEmailKey);
      _statusMessage = 'Biometric login disabled for this admin account.';
    }

    notifyListeners();
    return true;
  }

  void cacheAdminCredentials({
    required String email,
    required String password,
  }) {
    _lastAdminEmail = email.trim();
    _lastAdminPassword = password;
    if ((_rememberedAdminEmail?.isEmpty ?? true) && _lastAdminEmail!.isNotEmpty) {
      _rememberedAdminEmail = _lastAdminEmail;
    }
  }

  void beginAdminSession({String? adminEmail}) {
    _rememberedAdminEmail = adminEmail?.trim() ?? _rememberedAdminEmail;
    _isAdminSessionActive = true;
    _isSessionLocked = false;
    _statusMessage = null;
    markActivity(notify: false);
    notifyListeners();
  }

  Future<bool> unlockAdminSession() async {
    if (!canUseBiometricUnlock) {
      _statusMessage =
          'Biometric login is not ready on this device. Enable it from Admin Settings first.';
      notifyListeners();
      return false;
    }

    final authenticated = await authenticateWithBiometrics(
      reason: 'Verify identity to access the admin console.',
    );
    if (!authenticated) {
      return false;
    }

    _statusMessage = null;
    notifyListeners();
    return true;
  }

  void markActivity({bool notify = false}) {
    if (!_isAdminSessionActive || _isSessionLocked) {
      return;
    }

    _lastActivityAt = DateTime.now();
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, lockDueToTimeout);

    if (notify) {
      notifyListeners();
    }
  }

  void lockDueToTimeout() {
    _sessionTimer?.cancel();
    _isAdminSessionActive = false;
    _isSessionLocked = true;
    _statusMessage =
        'Admin session timed out after 10 minutes of inactivity.';
    notifyListeners();
  }

  void clearAdminSession({String? message}) {
    _sessionTimer?.cancel();
    _isAdminSessionActive = false;
    _isSessionLocked = false;
    _lastActivityAt = null;
    _lastAdminEmail = null;
    _lastAdminPassword = null;
    _statusMessage = message;
    notifyListeners();
  }

  void clearStatusMessage() {
    if (_statusMessage == null) {
      return;
    }
    _statusMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
