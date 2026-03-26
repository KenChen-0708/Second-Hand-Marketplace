import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  /// UPDATE: Saves the full UserModel back to the database
  Future<void> updateUserProfile(UserModel user) async {
    try {
      // We use the custom ID (e.g., 'U0001') to perform the update
      await supabase
          .from('users')
          .update(user.toMap())
          .eq('id', user.id);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  /// REGISTER: Auth SignUp + Fetch custom Profile
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

      // Wait for your SQL Trigger to finish inserting into public.users
      await Future.delayed(const Duration(milliseconds: 800));

      // IMPORTANT: Search by EMAIL because authUser.id is a UUID
      // but your users.id is 'Uxxxx'
      final data = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();

      return UserModel.fromMap(data);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// LOGIN: Authenticates and fetches the custom ID profile
  Future<UserModel> loginUser(String email, String password) async {
    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) throw Exception('Invalid credentials');

      // Again, fetch by EMAIL to bridge the UUID vs Custom ID gap
      final data = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();

      return UserModel.fromMap(data);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<void> logout() async => await supabase.auth.signOut();

  bool isLoggedIn() => supabase.auth.currentSession != null;
}
