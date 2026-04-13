import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth/biometric_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkTheme = false;
  bool _emailNotifs = true;
  bool _pushNotifs = true;
  bool _locationServices = false;
  bool _biometricEnabled = false;
  bool _biometricHardwareAvailable = false;
  final _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text(
            'Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Edit Profile'),
            leading: const Icon(Icons.person_outline_rounded),
            trailing: const Icon(Icons.chevron_right_rounded),
            contentPadding: EdgeInsets.zero,
            onTap: () => context.push('/profile/account'),
          ),
          const Divider(),
          const SizedBox(height: 24),

          const Text(
            'Appearance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Dark Theme'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: _isDarkTheme,
            onChanged: (val) => setState(() => _isDarkTheme = val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          const Divider(),
          const SizedBox(height: 24),

          const Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Email Notifications'),
            secondary: const Icon(Icons.email_outlined),
            value: _emailNotifs,
            onChanged: (val) => setState(() => _emailNotifs = val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            secondary: const Icon(Icons.notifications_active_outlined),
            value: _pushNotifs,
            onChanged: (val) => setState(() => _pushNotifs = val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          const Divider(),
          const SizedBox(height: 24),

          const Text(
            'Privacy & Security',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
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
          SwitchListTile(
            title: const Text('Location Services'),
            subtitle: const Text('Used to find nearby items'),
            secondary: const Icon(Icons.location_on_outlined),
            value: _locationServices,
            onChanged: (val) => setState(() => _locationServices = val),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
          ListTile(
            title: const Text('Change Password'),
            leading: const Icon(Icons.lock_outline),
            trailing: const Icon(Icons.chevron_right_rounded),
            contentPadding: EdgeInsets.zero,
            onTap: () {},
          ),
          const Divider(),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'App Version 1.0.0',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
