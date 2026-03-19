import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  /// Login with email and password
  /// Returns the matched user profile from the `users` table
  Future<UserModel> loginUser(String email, String password) async {
    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Login failed: Invalid credentials');
      }

      Map<String, dynamic>? userData;

      // Best case: your users.id matches auth.users.id
      try {
        final data = await supabase
            .from('users')
            .select()
            .eq('id', authUser.id)
            .single();

        userData = Map<String, dynamic>.from(data);
      } catch (_) {
        // Fallback: if your table uses a different UUID than auth.users.id,
        // try by email
        final data = await supabase
            .from('users')
            .select()
            .eq('email', authUser.email ?? email)
            .single();

        userData = Map<String, dynamic>.from(data);
      }

      return UserModel.fromMap(userData);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  bool isLoggedIn() {
    return supabase.auth.currentSession != null;
  }

  String? getCurrentUserId() {
    return supabase.auth.currentUser?.id;
  }

  String? getCurrentUserEmail() {
    return supabase.auth.currentUser?.email;
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Logout error: $e');
    }
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (_) {
      return null;
    } catch (e) {
      throw Exception('Error fetching user profile: $e');
    }
  }

  Future<UserModel?> getCurrentUserProfile() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return null;

    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      return UserModel.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException {
      if (authUser.email == null) return null;

      try {
        final data = await supabase
            .from('users')
            .select()
            .eq('email', authUser.email!)
            .single();

        return UserModel.fromMap(Map<String, dynamic>.from(data));
      } catch (e) {
        throw Exception('Error fetching current user profile: $e');
      }
    } catch (e) {
      throw Exception('Error fetching current user profile: $e');
    }
  }
}