import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../local/connectivity_service.dart';
import '../local/local_database_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient supabase = Supabase.instance.client;
  final LocalDatabaseService _localDatabase = LocalDatabaseService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;

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

  /// Fetches the user profile using their ID (e.g. 'U0001')
  Future<UserModel> fetchProfileById(String userId) async {
    final cachedProfile = await _localDatabase.getCachedUserProfileById(userId);
    if (!await _connectivityService.isOnline()) {
      if (cachedProfile != null) {
        return cachedProfile;
      }
      throw Exception('Profile unavailable while offline.');
    }

    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      final profile = UserModel.fromMap(data);
      await _localDatabase.cacheUserProfile(profile);
      return profile;
    } on PostgrestException catch (e) {
      if (cachedProfile != null) {
        return cachedProfile;
      }
      throw Exception(e.message);
    } catch (_) {
      if (cachedProfile != null) {
        return cachedProfile;
      }
      rethrow;
    }
  }

  /// Bridging Logic: Fetches the 'U0001' style profile using email
  Future<UserModel> fetchProfileByEmail(String email) async {
    final cachedProfile = await _localDatabase.getCachedUserProfileByEmail(email);
    if (!await _connectivityService.isOnline()) {
      if (cachedProfile != null) {
        return cachedProfile;
      }
      final authUser = supabase.auth.currentUser;
      return UserModel(
        id: cachedProfile?.id ?? authUser?.id ?? email,
        email: email,
        name: cachedProfile?.name ?? email.split('@').first,
        avatarUrl: cachedProfile?.avatarUrl,
        role: cachedProfile?.role ?? 'user',
        isActive: cachedProfile?.isActive ?? true,
        phoneNumber: cachedProfile?.phoneNumber,
        address: cachedProfile?.address,
        city: cachedProfile?.city,
        postalCode: cachedProfile?.postalCode,
        country: cachedProfile?.country,
        bio: cachedProfile?.bio,
        createdAt: cachedProfile?.createdAt,
        updatedAt: cachedProfile?.updatedAt,
      );
    }

    try {
      var data = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (data == null) {
        data = await supabase
            .from('users')
            .insert({
              'email': email,
              'name': email.split('@').first,
            })
            .select()
            .single();
      }

      final profile = UserModel.fromMap(data);
      await _localDatabase.cacheUserProfile(profile);
      return profile;
    } on PostgrestException catch (e) {
      if (cachedProfile != null) {
        return cachedProfile;
      }
      throw Exception(e.message);
    } catch (_) {
      if (cachedProfile != null) {
        return cachedProfile;
      }
      rethrow;
    }
  }

  /// LOGIN: Authenticates via Auth and then pulls the custom Profile
  Future<UserModel> loginUser(String email, String password) async {
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      final user = await fetchProfileByEmail(email);

      if (!user.isActive) {
        await logout(); // Immediately sign out if banned
        throw Exception('Your account has been suspended. Please contact the administrator.');
      }

      return user;
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

      await Future.delayed(const Duration(milliseconds: 1200));

      return await fetchProfileByEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// UPDATE: Saves the full UserModel back to the 'users' table
  Future<void> updateUserProfile(UserModel user) async {
    await _localDatabase.cacheUserProfile(user);

    if (!await _connectivityService.isOnline()) {
      return;
    }

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

  Future<void> verifyCurrentPassword(String currentPassword) async {
    final currentUser = supabase.auth.currentUser;
    final email = currentUser?.email;

    if (currentUser == null || email == null || email.isEmpty) {
      throw Exception('You must be logged in to change your password.');
    }

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
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
