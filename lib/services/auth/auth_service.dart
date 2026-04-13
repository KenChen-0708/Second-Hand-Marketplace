import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  /// Returns the current Supabase Auth user UUID for session checks.
  String? getCurrentAuthUserId() {
    return supabase.auth.currentUser?.id;
  }

  /// Returns the app profile ID (for example `U0001`) used by foreign keys.
  Future<String?> getCurrentUserId() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      return null;
    }

    final profile = await fetchProfileByEmail(email);
    return profile.id;
  }

  /// Bridging Logic: Fetches the 'U0001' style profile using email
  Future<UserModel> fetchProfileByEmail(String email) async {
    try {
      var data = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (data == null) {
        // Recovery logic if database was reset but Supabase Auth remains
        data = await supabase
            .from('users')
            .insert({
              'email': email,
              'name': email.split('@').first,
            })
            .select()
            .single();
      }

      return UserModel.fromMap(data);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// LOGIN: Authenticates via Auth and then pulls the custom Profile
  Future<UserModel> loginUser(String email, String password) async {
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      return await fetchProfileByEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// REGISTER: Auth SignUp -> Wait for Trigger -> Fetch Profile
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) throw Exception('Registration failed');

      // 1.2s delay ensures the Postgres Trigger has finished creating the 'Uxxx' ID
      await Future.delayed(const Duration(milliseconds: 1200));

      return await fetchProfileByEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// UPDATE: Saves the full UserModel back to the 'users' table
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await supabase
          .from('users')
          .update(user.toMap())
          .eq('id', user.id);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Change Password
  Future<void> changePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Reset Password (Forgot Password)
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> logout() async => await supabase.auth.signOut();
  bool isLoggedIn() => supabase.auth.currentSession != null;
}
