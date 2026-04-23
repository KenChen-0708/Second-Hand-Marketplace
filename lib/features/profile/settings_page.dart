import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth/biometric_service.dart';
import '../../services/notification/push_notification_service.dart';
import '../../state/state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _emailNotifs = true;
  bool _biometricEnabled = false;
  bool _biometricHardwareAvailable = false;
  bool _pushNotifs = false;
  String _biometricLabel = 'Biometrics';
  
  final _biometricService = BiometricService();
  final _pushNotificationService = PushNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _loadBiometricSettings();
    final pushEnabled = await _pushNotificationService.isEnabled();
    if (mounted) {
      setState(() {
        _pushNotifs = pushEnabled;
      });
      context.read<UserState>().updatePushPreference(pushEnabled);
    }
  }

  Future<void> _loadBiometricSettings() async {
    try {
      final available = await _biometricService.isBiometricAvailable();
      final enabled = await _biometricService.isBiometricEnabled();
      final label = await _biometricService.getBiometricLabel();
      if (mounted) {
        setState(() {
          _biometricHardwareAvailable = available;
          _biometricEnabled = enabled;
          _biometricLabel = label;
        });
      }
    } catch (e) {
      debugPrint("SettingsPage: Failed to load biometric settings: $e");
    }
  }

  Future<void> _handlePushNotificationsToggle(bool value) async {
    final userState = context.read<UserState>();
    final user = userState.currentUser;
    if (user == null) return;

    setState(() => _pushNotifs = value);
    userState.updatePushPreference(value);

    try {
      if (value) {
        await _pushNotificationService.enableNotifications(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Push notifications enabled')),
          );
        }
      } else {
        await _pushNotificationService.disableNotifications(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Push notifications disabled')),
          );
        }
      }
    } catch (e) {
      setState(() => _pushNotifs = !value);
      userState.updatePushPreference(!value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    try {
      if (value) {
        final authenticated =
            await _biometricService.authenticateWithDeviceSecurity();
        if (authenticated) {
          await _biometricService.enableBiometrics();
          final hasCredentials = await _biometricService.hasStoredCredentials();
          setState(() => _biometricEnabled = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  hasCredentials
                      ? '$_biometricLabel login enabled.'
                      : '$_biometricLabel enabled. Please log in once to save your credentials.',
                ),
              ),
            );
          }
        }
      } else {
        await _biometricService.clearCredentials();
        setState(() => _biometricEnabled = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().contains("MissingPluginException") ? "Please restart the app" : e.toString()}')),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeState>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Push Notifications'),
            secondary: const Icon(Icons.notifications_active_outlined),
            value: _pushNotifs,
            onChanged: _handlePushNotificationsToggle,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          const Divider(),
          const SizedBox(height: 24),
          
          const Text('Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Edit Profile'),
            leading: const Icon(Icons.person_outline_rounded),
            trailing: const Icon(Icons.chevron_right_rounded),
            contentPadding: EdgeInsets.zero,
            onTap: () => context.push('/profile/edit'),
          ),
          const Divider(),
          const SizedBox(height: 24),

          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Dark Theme'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: themeState.isDarkMode,
            onChanged: (val) => themeState.toggleTheme(val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          const Divider(),
          const SizedBox(height: 24),

          const Text('Privacy & Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          if (_biometricHardwareAvailable)
            SwitchListTile(
              title: const Text('Biometric Login'),
              subtitle: Text('Use $_biometricLabel to log in'),
              secondary: const Icon(Icons.fingerprint),
              value: _biometricEnabled,
              onChanged: _toggleBiometrics,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Theme.of(context).colorScheme.primary,
            ),
          ListTile(
            title: const Text('Change Password'),
            leading: const Icon(Icons.lock_outline),
            trailing: const Icon(Icons.chevron_right_rounded),
            contentPadding: EdgeInsets.zero,
            onTap: _showChangePasswordDialog,
          ),
          const Divider(),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'App Version 1.0.0',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isVerifyingCurrentPassword = false;
  bool _currentPasswordVerified = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;

  double _strengthValue = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.grey;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      if (!mounted) return;
      setState(() {
        _strengthValue = 0;
        _strengthLabel = '';
        _strengthColor = Colors.grey;
      });
      return;
    }

    double score = 0;
    if (password.length >= 8) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.25;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 0.25;

    if (!mounted) return;
    setState(() {
      _strengthValue = score;
      if (score <= 0.25) {
        _strengthLabel = 'Weak';
        _strengthColor = Colors.red;
      } else if (score <= 0.5) {
        _strengthLabel = 'Fair';
        _strengthColor = Colors.orange;
      } else if (score <= 0.75) {
        _strengthLabel = 'Good';
        _strengthColor = Colors.blue;
      } else {
        _strengthLabel = 'Strong';
        _strengthColor = Colors.green;
      }
    });
  }

  Future<void> _verifyCurrentPassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    if (currentPassword.isEmpty) {
      _formKey.currentState!.validate();
      return;
    }

    setState(() => _isVerifyingCurrentPassword = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await context.read<UserState>().verifyCurrentPassword(currentPassword);
      if (!mounted) return;
      setState(() => _currentPasswordVerified = true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Current password verified')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _currentPasswordVerified = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Verification failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingCurrentPassword = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_currentPasswordVerified) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please verify your current password first'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<UserState>().changePassword(
        _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodySmallStyle = Theme.of(context).textTheme.bodySmall;

    return AlertDialog(
      title: const Text('Change Password'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  onChanged: (_) {
                    if (_currentPasswordVerified) {
                      setState(() => _currentPasswordVerified = false);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    hintText: 'Enter current password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      }),
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _isLoading || _isVerifyingCurrentPassword
                      ? null
                      : _verifyCurrentPassword,
                  child: _isVerifyingCurrentPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _currentPasswordVerified
                              ? 'Current Password Verified'
                              : 'Verify Current Password',
                        ),
                ),
                if (!_currentPasswordVerified) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Verify your current password before entering a new one.',
                    style: bodySmallStyle,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: _currentPasswordVerified,
                  obscureText: _obscureNewPassword,
                  onChanged: (_) => _checkStrength(),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter new password',
                    suffixIcon: IconButton(
                      onPressed: _currentPasswordVerified
                          ? () => setState(() {
                              _obscureNewPassword = !_obscureNewPassword;
                            })
                          : null,
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (!_currentPasswordVerified) return null;
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Minimum 6 characters required';
                    }
                    if (value == _currentPasswordController.text) {
                      return 'New password must be different from current password';
                    }
                    return null;
                  },
                ),
                if (_currentPasswordVerified &&
                    _passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _strengthValue,
                      backgroundColor: Colors.grey[200],
                      color: _strengthColor,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _strengthLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _strengthColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: _currentPasswordVerified,
                  obscureText: _obscureNewPassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter new password',
                  ),
                  validator: (value) {
                    if (!_currentPasswordVerified) return null;
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}
