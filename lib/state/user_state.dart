import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth/auth_service.dart';

class UserState extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

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

  /// Profile Update: Supports every field in your UserModel
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

    // Create a copy of the current user with the new values
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
      // Persist to Database
      await _authService.updateUserProfile(updatedUser);

      // Update Local State
      _currentUser = updatedUser;
      notifyListeners();
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