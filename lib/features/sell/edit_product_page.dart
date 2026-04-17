import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../state/state.dart';
import '../../services/product/product_service.dart';

class EditProductPage extends StatefulWidget {
  final ProductModel product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late String _selectedCondition;
  bool _faceToFace = false;
  bool _delivery = false;
  String? _deliveryMethod;
  final _locationController = TextEditingController();
  bool _openToOffers = false;
  final List<String> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Parse description to extract meeting location if it exists (Legacy support)
    String description = widget.product.description;
    if (description.contains('\n\n---\nMeeting Location:\n• ')) {
      description = description.split('\n\n---\nMeeting Location:\n• ')[0];
    }

    _titleController = TextEditingController(text: widget.product.title);
    _descriptionController = TextEditingController(text: description);
    _priceController =
        TextEditingController(text: widget.product.price.toString());
    _selectedCondition = widget.product.condition;
    _openToOffers = widget.product.openToOffers;

    _loadMeetupLocation();

    // Map trade preference to UI flags
    final prefs = widget.product.tradePreference;
    if (prefs.contains('face_to_face')) {
      _faceToFace = true;
    }
    
    final deliveryPref = prefs.firstWhere(
      (p) => p.startsWith('delivery_'),
      orElse: () => '',
    );
    if (deliveryPref.isNotEmpty) {
      _delivery = true;
      _deliveryMethod = deliveryPref.replaceFirst('delivery_', '');
    }
    
    // Initialize images
    if (widget.product.images != null && widget.product.images!.isNotEmpty) {
      _images.addAll(widget.product.images!);
    } else if (widget.product.imageUrl != null) {
      _images.add(widget.product.imageUrl!);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) {
        setState(() {
          for (var img in picked) {
            if (_images.length < 10 && !_images.contains(img.path)) {
              _images.add(img.path);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo != null && _images.length < 10) {
        setState(() => _images.add(photo.path));
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _loadMeetupLocation() async {
    try {
      final location = await ProductService().fetchMeetupLocation(widget.product.id);
      if (location != null && mounted) {
        setState(() {
          _locationController.text = location['location_name'] ?? location['address'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading meetup location: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userState = context.read<UserState>();
      final userId = userState.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final productService = ProductService();
      
      // Separate existing URLs from new local paths
      final existingUrls = _images.where((img) => img.startsWith('http')).toList();
      final newPaths = _images.where((img) => !img.startsWith('http')).toList();

      List<String> uploadedUrls = [];
      if (newPaths.isNotEmpty) {
        uploadedUrls = await productService.uploadImages(newPaths, userId);
      }

      final allImageUrls = [...existingUrls, ...uploadedUrls];

      // 6. Determine Trade Preference (Multi-select)
      List<String> tradePreferences = [];
      if (_faceToFace) {
        tradePreferences.add('face_to_face');
      }
      if (_delivery) {
        tradePreferences.add(
          _deliveryMethod == 'official' ? 'delivery_official' : 'delivery_self',
        );
      }
      if (tradePreferences.isEmpty) tradePreferences = ['face_to_face'];

      // 7. Format Description
      String finalDescription = _descriptionController.text.trim();
      // Remove previous meeting location block if present to avoid duplicates (Legacy cleanup)
      finalDescription = finalDescription.split('\n\n---\nMeeting Location:')[0];

      final updateData = {
        'title': _titleController.text.trim(),
        'description': finalDescription,
        'price': price,
        'condition': _selectedCondition,
        'trade_preference': tradePreferences,
        'open_to_offers': _openToOffers,
        'image_urls': allImageUrls,
      };

      await context.read<ProductState>().updateProduct(widget.product.id, updateData);

      // 8. Update Meetup Location in its own table
      if (_faceToFace && _locationController.text.isNotEmpty) {
        await productService.updateMeetupLocation(widget.product.id, {
          'location_name': _locationController.text.trim(),
          'address': _locationController.text.trim(),
          'is_default': true,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Photos'),
            const SizedBox(height: 12),
            _buildImageSection(),
            const SizedBox(height: 24),
            _SectionLabel('Item Title'),
            const SizedBox(height: 10),
            _StyledField(
              controller: _titleController,
              hint: 'e.g. MacBook Pro 2021',
              icon: Icons.title_rounded,
            ),
            const SizedBox(height: 24),
            _SectionLabel('Price'),
            const SizedBox(height: 10),
            _StyledField(
              controller: _priceController,
              hint: '0.00',
              icon: Icons.sell_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixText: r'$ ',
            ),
            const SizedBox(height: 24),
            _SectionLabel('Condition'),
            const SizedBox(height: 12),
            _buildConditionDropdown(),
            const SizedBox(height: 24),
            _SectionLabel('Description'),
            const SizedBox(height: 10),
            _StyledField(
              controller: _descriptionController,
              hint: 'Describe what you are selling...',
              icon: Icons.notes_rounded,
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            _SectionLabel('Trade Method'),
            const SizedBox(height: 12),
            _TradeOptionCard(
              icon: Icons.handshake_rounded,
              title: 'Face-to-Face',
              subtitle: 'Meet the buyer in person at a safe location.',
              selected: _faceToFace,
              onTap: () => setState(() => _faceToFace = !_faceToFace),
            ),
            if (_faceToFace) ...[
              const SizedBox(height: 12),
              _StyledField(
                controller: _locationController,
                hint: 'e.g. Campus Library, Ground Floor',
                icon: Icons.location_on_rounded,
                label: 'Meeting Location',
              ),
            ],
            const SizedBox(height: 14),
            _TradeOptionCard(
              icon: Icons.local_shipping_rounded,
              title: 'Delivery',
              subtitle: 'Ship the item to the buyer.',
              selected: _delivery,
              onTap: () => setState(() {
                _delivery = !_delivery;
                if (_delivery && _deliveryMethod == null) {
                  _deliveryMethod = 'official';
                }
              }),
            ),
            if (_delivery) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DeliveryMethodTile(
                      icon: Icons.business_center_rounded,
                      label: 'Official Delivery',
                      selected: _deliveryMethod == 'official',
                      onTap: () => setState(() => _deliveryMethod = 'official'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DeliveryMethodTile(
                      icon: Icons.directions_bike_rounded,
                      label: 'Self-Delivery',
                      selected: _deliveryMethod == 'self',
                      onTap: () => setState(() => _deliveryMethod = 'self'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _OfferToggle(
              value: _openToOffers,
              onChanged: (v) => setState(() => _openToOffers = v),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildConditionDropdown() {
    final conditions = [
      {'label': 'Like New', 'value': 'like_new'},
      {'label': 'Excellent', 'value': 'excellent'},
      {'label': 'Good', 'value': 'good'},
      {'label': 'Fair', 'value': 'fair'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCondition,
          isExpanded: true,
          items: conditions.map((c) {
            return DropdownMenuItem<String>(
              value: c['value'],
              child: Text(c['label']!),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCondition = val);
          },
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final colors = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        if (_images.isEmpty)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withOpacity(0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: colors.primary, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Add up to 10 photos',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length + (_images.length < 10 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded),
                              title: const Text('Choose from Gallery'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImages();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt_rounded),
                              title: const Text('Take a Photo'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _takePhoto();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Icon(Icons.add_rounded, color: colors.primary),
                    ),
                  );
                }

                final imagePath = _images[index];
                final isUrl = imagePath.startsWith('http');

                return Stack(
                  children: [
                    Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: isUrl 
                              ? NetworkImage(imagePath) as ImageProvider
                              : FileImage(File(imagePath)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Cover',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'The first photo will be used as the cover.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Helpers (Replicated from SellPage for consistency)
// ─────────────────────────────────────────────────────────────────────────────
class _TradeOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TradeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? colors.primary : colors.outline.withOpacity(0.15),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : colors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withOpacity(0.55),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? colors.primary : colors.outline.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryMethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? colors.primary : colors.outline.withOpacity(0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : colors.primary,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : colors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferToggle extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;

  const _OfferToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? colors.primary.withOpacity(0.07) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? colors.primary.withOpacity(0.14) : colors.outline.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Open to Offers',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  'Allow buyers to negotiate the price',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final Widget? suffixIcon;
  final int maxLines;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.label,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.suffixIcon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFC),
        prefixText: prefixText,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6, right: 2),
          child: Icon(icon, color: colors.primary, size: 20),
        ),
        suffixIcon: suffixIcon,
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}
