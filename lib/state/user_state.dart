import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/biometric_service.dart';
import '../../services/auth/presence_service.dart';
import '../../services/notification/push_notification_service.dart';

class UserState extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get isAuthenticated => _authService.isLoggedIn();

  /// Initialize: Checks if a session exists and loads the profile
  Future<void> initialize() async {
    if (_authService.isLoggedIn()) {
      final email = _authService.supabase.auth.currentUser?.email;
      if (email != null) {
        try {
          _currentUser = await _authService.fetchProfileByEmail(email);
          if (_currentUser != null && !_currentUser!.isActive) {
            await logout();
            return;
          }
        } catch (e) {
          _currentUser = UserModel(
            id: _authService.supabase.auth.currentUser?.id ?? email,
            email: email,
            name: email.split('@').first,
          );
        }
      }
    }

    await PushNotificationService.instance.registerSignedInUser(_currentUser?.id);
    await PresenceService.instance.setCurrentUser(_currentUser?.id);
    
    // Load local preference immediately on boot
    await syncPushPreference();
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Explicitly sync the push preference from local storage
  Future<void> syncPushPreference() async {
    if (_currentUser != null) {
      final pushEnabled = await PushNotificationService.instance.isEnabled();
      if (_currentUser!.pushEnabled != pushEnabled) {
        _currentUser = _currentUser!.copyWith(pushEnabled: pushEnabled);
        notifyListeners();
      }
    }
  }

  /// Update just the push notification preference locally and in memory
  void updatePushPreference(bool enabled) {
    if (_currentUser != null && _currentUser!.pushEnabled != enabled) {
      _currentUser = _currentUser!.copyWith(pushEnabled: enabled);
      notifyListeners();
    }
  }

  /// Standard Login
  Future<void> login(String email, String password) async {
    _currentUser = await _authService.loginUser(email, password);
    await PushNotificationService.instance.registerSignedInUser(_currentUser?.id);
    await PresenceService.instance.setCurrentUser(_currentUser?.id);
    await syncPushPreference();
    notifyListeners();
  }

  /// Standard Registration
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _currentUser = await _authService.registerUser(
      email: email,
      password: password,
      name: name,
    );
    await PushNotificationService.instance.registerSignedInUser(_currentUser?.id);
    await PresenceService.instance.setCurrentUser(_currentUser?.id);
    await syncPushPreference();
    notifyListeners();
  }

  /// Profile Update
  Future<void> updateProfile({
    String? name,
    String? phoneNumber,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return;

    final updatedUser = _currentUser!.copyWith(
      name: name,
      phoneNumber: phoneNumber,
      address: address,
      city: city,
      postalCode: postalCode,
      country: country,
      bio: bio,
      avatarUrl: avatarUrl,
      updatedAt: DateTime.now(),
    );

    try {
      await _authService.updateUserProfile(updatedUser);
      // Keep push enabled status after DB update
      final currentPush = _currentUser!.pushEnabled;
      _currentUser = updatedUser.copyWith(pushEnabled: currentPush);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword(String newPassword) async {
    try {
      await _authService.changePassword(newPassword);
      await BiometricService().clearCredentials();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await PresenceService.instance.markOffline();
    await _authService.logout();
    await PresenceService.instance.setCurrentUser(null);
    await PushNotificationService.instance.unregisterSignedInUser();
    _currentUser = null;
    notifyListeners();
  }
}
