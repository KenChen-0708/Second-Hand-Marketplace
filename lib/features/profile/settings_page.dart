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
      if (mounted) {
        setState(() {
          _biometricHardwareAvailable = available;
          _biometricEnabled = enabled;
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
        final authenticated = await _biometricService.authenticate();
        if (authenticated) {
          await _biometricService.saveCredentials("", ""); 
          setState(() => _biometricEnabled = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometrics enabled. Please login manually once to save credentials.')),
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
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    
    double strengthValue = 0;
    String strengthLabel = '';
    Color strengthColor = Colors.grey;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          void checkStrength() {
            final password = passwordController.text;
            if (password.isEmpty) {
              setDialogState(() {
                strengthValue = 0;
                strengthLabel = '';
              });
              return;
            }

            double score = 0;
            if (password.length >= 8) score += 0.25;
            if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.25;
            if (RegExp(r'[0-9]').hasMatch(password)) score += 0.25;
            if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 0.25;

            setDialogState(() {
              strengthValue = score;
              if (score <= 0.25) {
                strengthLabel = 'Weak';
                strengthColor = Colors.red;
              } else if (score <= 0.5) {
                strengthLabel = 'Fair';
                strengthColor = Colors.orange;
              } else if (score <= 0.75) {
                strengthLabel = 'Good';
                strengthColor = Colors.blue;
              } else {
                strengthLabel = 'Strong';
                strengthColor = Colors.green;
              }
            });
          }

          return AlertDialog(
            title: const Text('Change Password'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    onChanged: (_) => checkStrength(),
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter new password',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a password';
                      if (value.length < 6) return 'Minimum 6 characters required';
                      return null;
                    },
                  ),
                  
                  if (passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: strengthValue,
                        backgroundColor: Colors.grey[200],
                        color: strengthColor,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strengthLabel,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: strengthColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter new password',
                    ),
                    validator: (value) {
                      if (value != passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isLoading = true);
                          try {
                            await context.read<UserState>().changePassword(passwordController.text);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password changed successfully')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}')),
                              );
                            }
                          } finally {
                            if (context.mounted) setDialogState(() => isLoading = false);
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Change'),
              ),
            ],
          );
        },
      ),
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
              subtitle: const Text('Use fingerprint or face ID to log in'),
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
