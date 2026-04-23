import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../state/state.dart';
import '../../shared/utils/image_helper.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _postalController;
  String? _selectedCountry;
  String _selectedCountryCode = '+60';
  
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  final List<String> _countries = [
    'Malaysia',
    'Singapore',
    'Indonesia',
    'Thailand',
    'Vietnam',
    'Philippines',
    'China',
    'India',
    'Other'
  ];

  final Map<String, String> _countryCodes = {
    'Malaysia': '+60',
    'Singapore': '+65',
    'Indonesia': '+62',
    'Thailand': '+66',
    'Vietnam': '+84',
    'Philippines': '+63',
    'China': '+86',
    'India': '+91',
    'Other': '+1',
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<UserState>().currentUser;

    _nameController = TextEditingController(text: user?.name ?? '');
    
    // Parse country code and number if possible
    String fullPhone = user?.phoneNumber ?? '';
    if (fullPhone.startsWith('+')) {
      for (var entry in _countryCodes.entries) {
        if (fullPhone.startsWith(entry.value)) {
          _selectedCountryCode = entry.value;
          fullPhone = fullPhone.substring(entry.value.length);
          break;
        }
      }
    }
    _phoneController = TextEditingController(text: fullPhone);
    
    _bioController = TextEditingController(text: user?.bio ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _postalController = TextEditingController(text: user?.postalCode ?? '');
    
    if (user?.country != null && _countries.contains(user!.country)) {
      _selectedCountry = user.country;
    } else {
      _selectedCountry = 'Malaysia';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userState = context.read<UserState>();
      final currentUser = userState.currentUser;
      String? avatarUrl = currentUser?.avatarUrl;

      if (_pickedImage != null && currentUser != null) {
        try {
          final bytes = await _pickedImage!.readAsBytes();
          final mimeType = _pickedImage!.mimeType ?? 'image/jpeg';
          
          final uploadedFileName = await ImageHelper.uploadProfileImage(
            bytes, 
            currentUser.id,
            mimeType,
          );
          if (uploadedFileName != null) {
            avatarUrl = uploadedFileName;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo upload failed: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      final fullPhoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';

      await userState.updateProfile(
        name: _nameController.text.trim(),
        phoneNumber: fullPhoneNumber,
        bio: _bioController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalController.text.trim(),
        country: _selectedCountry,
        avatarUrl: avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserState>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user found. Please log in.")));
    }

    final String displayAvatarUrl = ImageHelper.resolveProfileImageUrl(user.avatarUrl, name: user.name);

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest,
                        border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 2),
                      ),
                      child: ClipOval(
                        child: _buildAvatarPreview(displayAvatarUrl),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.surface, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle(context, 'Basic Information'),
              _buildTextField(
                context,
                'Full Name',
                _nameController,
                enabled: !_isLoading,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (v.trim().length < 2) return 'Name is too short';
                  if (v.trim().length > 50) return 'Name is too long';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildPhoneField(context),
              const SizedBox(height: 16),

              _buildTextField(
                context,
                'Bio',
                _bioController,
                enabled: !_isLoading,
                hintText: 'Tell other students about yourself...',
                maxLines: 3,
                validator: (v) {
                  if (v != null && v.length > 200) return 'Bio must be less than 200 characters';
                  return null;
                },
              ),

              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Address Details'),

              _buildTextField(
                context, 
                'Street Address', 
                _addressController, 
                enabled: !_isLoading,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length < 5) return 'Address is too short';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      context, 
                      'City', 
                      _cityController, 
                      enabled: !_isLoading,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && v.length < 2) return 'Invalid city';
                        return null;
                      },
                    )
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      context, 
                      'Postal Code', 
                      _postalController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          if (!RegExp(r'^[0-9]{5,10}$').hasMatch(v)) {
                            return 'Invalid postal code';
                          }
                        }
                        return null;
                      },
                    )
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildCountryDropdown(context),

              const SizedBox(height: 40),

              FilledButton(
                onPressed: _isLoading ? null : _handleSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 50,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  isExpanded: true,
                  onChanged: _isLoading ? null : (val) => setState(() => _selectedCountryCode = val!),
                  items: _countryCodes.values.toSet().map((code) {
                    return DropdownMenuItem(value: code, child: Text(code));
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'e.g. 123456789',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!RegExp(r'^[0-9]{7,12}$').hasMatch(v.replaceAll(' ', ''))) {
                      return 'Invalid number';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarPreview(String displayAvatarUrl) {
    if (_pickedImage != null) {
      if (kIsWeb) {
        return Image.network(_pickedImage!.path, fit: BoxFit.cover);
      } else {
        return Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
      }
    }

    return Image.network(
      displayAvatarUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return Image.network(ImageHelper.getDefaultAvatarUrl(_nameController.text));
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
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
        int maxLines = 1,
        TextInputType? keyboardType,
        String? Function(String?)? validator,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Country',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCountry,
          decoration: InputDecoration(
            enabled: !_isLoading,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _countries.map((String country) {
            return DropdownMenuItem<String>(
              value: country,
              child: Text(country),
            );
          }).toList(),
          onChanged: _isLoading ? null : (String? newValue) {
            setState(() {
              _selectedCountry = newValue;
              // Sync country code
              if (newValue != null && _countryCodes.containsKey(newValue)) {
                _selectedCountryCode = _countryCodes[newValue]!;
              }
            });
          },
          validator: (value) => value == null ? 'Please select a country' : null,
        ),
      ],
    );
  }
}
