import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  /// NEW: Update User Profile in Database
  /// This keeps the UI decoupled from Supabase syntax
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await supabase.from('users').update(user.toMap()).eq('id', user.id);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  /// REGISTER: Creates Auth user + Trigger handles Public Profile
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      final authUser = response.user;
      if (authUser == null) throw Exception('Registration failed');

      // Add a tiny delay if you still hit the "0 rows" timing issue
      await Future.delayed(const Duration(milliseconds: 500));

      final data = await supabase
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      return UserModel.fromMap(Map<String, dynamic>.from(data));
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// LOGIN: Authenticates and fetches Profile
  Future<UserModel> loginUser(String email, String password) async {
    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) throw Exception('Invalid credentials');

      final data = await supabase
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      return UserModel.fromMap(Map<String, dynamic>.from(data));
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<void> logout() async => await supabase.auth.signOut();
  bool isLoggedIn() => supabase.auth.currentSession != null;
  String? getCurrentUserId() => supabase.auth.currentUser?.id;
}
