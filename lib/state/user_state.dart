import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth/auth_service.dart';

class UserState extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  
  bool get isAuthenticated => _authService.isLoggedIn();

  /// Initialize: Checks if a session exists and loads the profile
  Future<void> initialize() async {
    if (_authService.isLoggedIn()) {
      final email = _authService.supabase.auth.currentUser?.email;
      if (email != null) {
        try {
          _currentUser = await _authService.fetchProfileByEmail(email);
          notifyListeners();
        } catch (e) {
          // If profile fetch fails, logout to be safe
          await logout();
        }
      }
    }
  }

  /// Standard Login
  Future<void> login(String email, String password) async {
    _currentUser = await _authService.loginUser(email, password);
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
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Change Password
  Future<void> changePassword(String newPassword) async {
    try {
      await _authService.changePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }

  /// Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}
