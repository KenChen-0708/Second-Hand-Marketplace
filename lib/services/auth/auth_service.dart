import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient supabase = Supabase.instance.client;

  /// Returns the internal Supabase UUID
  /// Required for session tracking in other states like CartState
  String? getCurrentUserId() {
    return supabase.auth.currentUser?.id;
  }

  /// Bridging Logic: Fetches the 'U0001' style profile using email
  Future<UserModel> fetchProfileByEmail(String email) async {
    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();
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

  Future<void> logout() async => await supabase.auth.signOut();
  bool isLoggedIn() => supabase.auth.currentSession != null;
}
