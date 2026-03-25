import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth/auth_service.dart';

class UserState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// 1. LOGIN: UI calls this -> State calls Service
  Future<void> login(String email, String password) async {
    try {
      final user = await _authService.loginUser(email, password);
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 2. REGISTER: UI calls this -> State calls Service
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final user = await _authService.registerUser(
        email: email,
        password: password,
        name: name,
      );
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 3. UPDATE PROFILE: Prepare Model -> Service -> Memory
  Future<void> updateProfile({required String name, required String phone}) async {
    if (_currentUser == null) return;

    final updatedUser = _currentUser!.copyWith(
      name: name,
      phoneNumber: phone,
    );

    try {
      await _authService.updateUserProfile(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 4. LOGOUT
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  /// Manual override (e.g., for initialization)
  void setCurrentUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }
}