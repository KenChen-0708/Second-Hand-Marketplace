import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class AdminUserState extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<UserModel> _users = [];
  bool _isLoading = false;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;

  Future<void> fetchAllUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);

      _users = (response as List).map((m) => UserModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await _supabase
          .from('users')
          .update({'is_active': !currentStatus})
          .eq('id', userId);
      
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isActive: !currentStatus);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating user status: $e');
      rethrow;
    }
  }
  
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _supabase
          .from('users')
          .update({'role': newRole})
          .eq('id', userId);
      
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(role: newRole);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }
}
