import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/state.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final _formKey = GlobalKey<FormState>();

  // 1. Controllers to hold the "live" text input
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 2. Initialize with real data from State
    final user = context.read<UserState>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 🔥 UI -> STATE: Page tells State to handle the update
      await context.read<UserState>().updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3. Watch the state for the current user object
    final user = context.watch<UserState>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user found. Please log in.")));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(user.avatarUrl ?? 'https://i.pravatar.cc/150'),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.surface, width: 3),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                          onPressed: () {
                            // Logic for image picking would go into UserState too!
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                context,
                'Full Name',
                _nameController,
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                context,
                'Student Email',
                TextEditingController(text: user.email),
                enabled: false,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                context,
                'Phone Number',
                _phoneController,
                hintText: 'e.g. +60123456789',
              ),

              const SizedBox(height: 32),

              FilledButton(
                onPressed: _isLoading ? null : _handleSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context,
      String label,
      TextEditingController controller, {
        bool enabled = true,
        String? hintText,
        String? Function(String?)? validator,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: !enabled,
            fillColor: !enabled
                ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : null,
          ),
        ),
      ],
    );
  }
}