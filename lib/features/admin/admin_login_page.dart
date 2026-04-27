import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth/admin_biometric_service.dart';
import '../../state/state.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _biometricService = AdminBiometricService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _didLoadAdminSecurityDefaults = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    final adminSecurityState = context.read<AdminSecurityState>();
    adminSecurityState.clearStatusMessage();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Login using UserState
      await context.read<UserState>().login(email, password);

      // Check if the logged-in user is an admin
      final userState = context.read<UserState>();
      final currentUser = userState.currentUser;

      if (currentUser == null) {
        throw Exception('User not found');
      }

      if (currentUser.role != 'admin') {
        // Not an admin, logout and show error
        await userState.logout();
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Access denied. Admin privileges required.';
          _isLoading = false;
        });
        return;
      }

      adminSecurityState.cacheAdminCredentials(
        email: email,
        password: password,
      );
      adminSecurityState.beginAdminSession(adminEmail: email);

      // Successfully logged in as admin
      if (!mounted) return;
      context.go('/admin/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBiometricUnlock() async {
    final adminSecurityState = context.read<AdminSecurityState>();
    final userState = context.read<UserState>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credentials = await _biometricService.getCredentials();
      if (credentials == null) {
        throw Exception(
          'No saved admin biometric credentials were found. Sign in with your password once and enable biometric login from Admin Settings.',
        );
      }

      final unlocked = await adminSecurityState.unlockAdminSession();
      if (!unlocked) {
        throw Exception(
          adminSecurityState.statusMessage ?? 'Biometric verification failed.',
        );
      }

      await userState.login(
        credentials['email']!,
        credentials['password']!,
      );

      if (userState.currentUser?.role != 'admin') {
        await userState.logout();
        throw Exception('Saved biometric credentials do not belong to an admin account.');
      }

      adminSecurityState.cacheAdminCredentials(
        email: credentials['email']!,
        password: credentials['password']!,
      );
      adminSecurityState.beginAdminSession(
        adminEmail: credentials['email']!,
      );
      _emailController.text = credentials['email']!;

      if (!mounted) return;
      context.go('/admin/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adminSecurityState = context.read<AdminSecurityState>();
    if (_didLoadAdminSecurityDefaults || !adminSecurityState.isInitialized) {
      return;
    }

    if (_emailController.text.isEmpty &&
        (adminSecurityState.rememberedAdminEmail?.isNotEmpty ?? false)) {
      _emailController.text = adminSecurityState.rememberedAdminEmail!;
    }
    _didLoadAdminSecurityDefaults = true;
  }

  @override
  Widget build(BuildContext context) {
    final adminSecurityState = context.watch<AdminSecurityState>();
    final statusMessage = _errorMessage ?? adminSecurityState.statusMessage;
    final statusColor =
        _errorMessage != null ? Colors.red : const Color(0xFF1D4ED8);
    final canShowBiometricUnlock = adminSecurityState.canUseBiometricUnlock;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Header
                Center(
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Platform Administration',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Authorized Personnel Only',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Error Message
                if (statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        border: Border.all(color: statusColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Form Fields
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: const Icon(Icons.shield_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Email is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.timer_outlined, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Admin sessions lock after 10 minutes of inactivity.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Biometric login can be enabled from the admin Settings tab.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Login Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleAdminLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Access Back-Office',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                if (canShowBiometricUnlock) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleBiometricUnlock,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Login with Biometrics'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
