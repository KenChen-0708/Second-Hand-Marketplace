import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/state.dart';
import '../../services/auth/biometric_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _biometricService = BiometricService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
  }

  Future<void> _checkBiometrics() async {
    try {
      final available = await _biometricService.isBiometricAvailable();
      final enabled = await _biometricService.isBiometricEnabled();
      
      if (mounted) {
        setState(() {
          _isBiometricAvailable = available && enabled;
        });
      }
      
      if (available && enabled) {
        final credentials = await _biometricService.getCredentials();
        if (credentials != null) {
          _handleBiometricLogin();
        }
      }
    } catch (e) {
      debugPrint("Biometric check failed: $e");
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await context.read<UserState>().login(email, password);

      final userState = context.read<UserState>();
      final currentUser = userState.currentUser;

      // STRICT SEPARATION: Block admins from the student login portal
      if (currentUser != null && currentUser.role == 'admin') {
        await userState.logout();
        throw Exception('Admin accounts must use the Admin Login portal at the bottom of the page.');
      }

      // Save credentials for biometrics if enabled
      try {
        if (await _biometricService.isBiometricEnabled()) {
          await _biometricService.saveCredentials(email, password);
        }
      } catch (e) {
        debugPrint("Failed to save biometric credentials: $e");
      }

      if (!mounted) return;
      context.go('/home');

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_isLoading) return;

    try {
      final credentials = await _biometricService.getCredentials();
      if (credentials == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No biometric credentials saved. Please login manually once.')),
          );
        }
        return;
      }

      final authenticated = await _biometricService.authenticate();
      if (authenticated) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        await context.read<UserState>().login(
          credentials['email']!,
          credentials['password']!,
        );

        final userState = context.read<UserState>();
        if (userState.currentUser?.role == 'admin') {
          await userState.logout();
          throw Exception('Admins must use the Admin Login portal.');
        }

        if (!mounted) return;
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
         _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();
    bool isResetLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Form(
            key: resetFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter your email to receive a password reset link.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'name@example.com',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(text)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isResetLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isResetLoading
                  ? null
                  : () async {
                      if (resetFormKey.currentState!.validate()) {
                        setDialogState(() => isResetLoading = true);
                        try {
                          await context.read<UserState>().resetPassword(resetEmailController.text.trim());
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password reset email sent!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
                            );
                          }
                        } finally {
                          if (context.mounted) setDialogState(() => isResetLoading = false);
                        }
                      }
                    },
              child: isResetLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      filled: true,
      fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 48),

                          Center(
                            child: Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.eco_rounded,
                                size: 64,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Log in to your student account to continue buying and selling.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),

                          const SizedBox(height: 40),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          TextFormField(
                            controller: _emailController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: _inputDecoration(
                              context: context,
                              labelText: 'Email',
                              hintText: 'name@example.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(text)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: _inputDecoration(
                              context: context,
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final text = value ?? '';
                              if (text.isEmpty) {
                                return 'Password is required';
                              }
                              if (text.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _showForgotPasswordDialog,
                              child: const Text('Forgot Password?'),
                            ),
                          ),

                          const SizedBox(height: 24),

                          FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          OutlinedButton(
                            onPressed: _isLoading ? null : () => context.go('/home'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: colorScheme.primary, width: 1.5),
                            ),
                            child: const Text(
                              'Continue as Guest',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          if (_isBiometricAvailable)
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleBiometricLogin,
                              icon: const Icon(Icons.fingerprint, size: 24),
                              label: const Text(
                                'Login with Biometrics',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => context.push('/register'),
                                child: const Text('Register an Account'),
                              ),
                            ],
                          ),

                          const Spacer(),

                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Center(
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => context.push('/admin/login'),
                                child: Text(
                                  'Admin Login',
                                  style: TextStyle(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
