import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/state.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  Future<void> _toggleBiometricLock(
    BuildContext context,
    bool enabled,
  ) async {
    final adminSecurityState = context.read<AdminSecurityState>();
    final saved = await adminSecurityState.setBiometricPreference(
      enabled: enabled,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? (enabled
                    ? 'Biometric login enrolled. Next admin sign-in can use biometrics directly.'
                    : 'Biometric login disabled for this admin device.')
              : (adminSecurityState.statusMessage ??
                    'Unable to update biometric login setting.'),
        ),
        backgroundColor: saved ? null : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminSecurityState = context.watch<AdminSecurityState>();
    final currentUser = context.watch<UserState>().currentUser;
    final canEnableBiometrics = adminSecurityState.isBiometricAvailable;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Settings',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage admin-only security preferences for this device.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Login',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'When enabled, the admin login page will show a biometric button after this device returns to the admin lock screen.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile.adaptive(
                      value: adminSecurityState.isBiometricEnabled,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Allow biometric login',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        canEnableBiometrics
                            ? 'Use fingerprint or face recognition for admin re-entry on this device.'
                            : 'Fingerprint or face recognition is not available on this device.',
                      ),
                      onChanged: canEnableBiometrics
                          ? (value) => _toggleBiometricLock(context, value)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _AdminSecurityInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Admin account',
                      value:
                          currentUser?.email ??
                          adminSecurityState.rememberedAdminEmail ??
                          'Not available',
                    ),
                    const SizedBox(height: 12),
                    const _AdminSecurityInfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Session timeout',
                      value: '10 minutes of inactivity',
                    ),
                    if (adminSecurityState.isBiometricEnabled) ...[
                      const SizedBox(height: 12),
                      const _AdminSecurityInfoRow(
                        icon: Icons.login_outlined,
                        label: 'Login page behavior',
                        value: 'Shows biometric button for admin unlock',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSecurityInfoRow extends StatelessWidget {
  const _AdminSecurityInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
