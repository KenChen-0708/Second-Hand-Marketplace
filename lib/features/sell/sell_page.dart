import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'MapSelectionScreen.dart';
import '../../services/auth/auth_service.dart';
import '../../services/product/product_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry screen – shown as the /sell shell branch
// ─────────────────────────────────────────────────────────────────────────────
class SellPage extends StatelessWidget {
  const SellPage({super.key});

  void _openWizard(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        pageBuilder: (_, __, ___) => const _SellWizard(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Sell',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _openWizard(context),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Create Listing',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Snap a photo and list your item\nin minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.onSurface.withOpacity(0.55),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: FilledButton.icon(
                onPressed: () => _openWizard(context),
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-step wizard
// ─────────────────────────────────────────────────────────────────────────────
class _SellWizard extends StatefulWidget {
  const _SellWizard();

  @override
  State<_SellWizard> createState() => _SellWizardState();
}

class _SellWizardState extends State<_SellWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // ── Shared state ──
  final List<String> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategory;
  String? _selectedSubcategory;
  final _nameController = TextEditingController();
  final _descriptionController =
      TextEditingController(); // <-- Added Description
  String? _selectedCondition;
  final _priceController = TextEditingController();
  bool _openToOffers = true;
  bool _faceToFace = false;
  bool _delivery = false;
  final _locationController = TextEditingController();
  String? _deliveryMethod;

  bool _isLoadingLocation = false;
  bool _isPublishing = false; // <-- Added publishing state

  List<Map<String, dynamic>> _categoriesList = [];
  List<Map<String, dynamic>> _subcategoriesList = [];
  bool _isLoadingCategories = true;
  bool _isLoadingSubcategories = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    void rebuild() {
      if (mounted) setState(() {});
    }

    _nameController.addListener(rebuild);
    _descriptionController.addListener(rebuild);
    _priceController.addListener(rebuild);
    _locationController.addListener(rebuild);
  }

  Future<void> _fetchCategories() async {
    try {
      final productService = ProductService();
      final cats = await productService.fetchCategories();
      if (mounted) {
        setState(() {
          _categoriesList = cats;
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _fetchSubcategories(String categoryId) async {
    setState(() {
      _isLoadingSubcategories = true;
      _subcategoriesList = [];
      _selectedSubcategory = null;
    });

    try {
      final productService = ProductService();
      final subs = await productService.fetchSubcategories(categoryId);
      if (mounted) {
        setState(() {
          _subcategoriesList = subs;
          _isLoadingSubcategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubcategories = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentStep = index);
  }

  bool get _canProceedStep0 => _selectedImages.isNotEmpty;
  bool get _canProceedStep1 => _selectedCategory != null && _selectedSubcategory != null;
  bool get _canProceedStep2 =>
      _nameController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty && // Require description
      _selectedCondition != null &&
      _priceController.text.trim().isNotEmpty;
  bool get _canProceedStep3 =>
      (_faceToFace || _delivery) &&
      (!_faceToFace || _locationController.text.trim().isNotEmpty) &&
      (!_delivery || _deliveryMethod != null);

  bool _canProceed(int step) {
    switch (step) {
      case 0:
        return _canProceedStep0;
      case 1:
        return _canProceedStep1;
      case 2:
        return _canProceedStep2;
      case 3:
        return _canProceedStep3;
      default:
        return true;
    }
  }

  // ── Hardware Integration: Camera & Gallery ──
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo != null && _selectedImages.length < 10) {
        setState(() => _selectedImages.add(photo.path));
      }
    } catch (e) {
      debugPrint("Error taking photo: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);
      if (images.isNotEmpty) {
        setState(() {
          for (var img in images) {
            if (_selectedImages.length < 10 &&
                !_selectedImages.contains(img.path)) {
              _selectedImages.add(img.path);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error picking from gallery: $e");
    }
  }

  // ── Hardware Integration: GPS Location ──
  Future<void> _fetchGPSLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS is turned off. Opening location settings...'),
            ),
          );
        }
        await Geolocator.openLocationSettings();
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions were denied by the user.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissions denied forever. Opening app settings...',
              ),
            ),
          );
        }
        await Geolocator.openAppSettings();
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = [
          place.street,
          place.subLocality,
          place.locality,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() => _locationController.text = address);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _openInteractiveMap() async {
    setState(() => _isLoadingLocation = true);
    double lat = 3.1390;
    double lng = 101.6869;

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    setState(() => _isLoadingLocation = false);
    if (!mounted) return;

    final selectedAddress = await Navigator.of(context, rootNavigator: true)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                MapSelectionScreen(initialLat: lat, initialLng: lng),
          ),
        );

    if (selectedAddress != null && selectedAddress is String) {
      setState(() => _locationController.text = selectedAddress);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ── Database Publish Logic
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    try {
      final authService = AuthService();
      final productService = ProductService();

      final authUser = authService.supabase.auth.currentUser;

      if (authUser == null) throw 'You must be logged in to create a listing.';

      // 1. Get the custom U000X User ID from the users table
      final userProfile = await authService.fetchProfileByEmail(
        authUser.email!,
      );
      final sellerId = userProfile.id;

      // 2. Resolve Category ID & Subcategory ID
      final categoryId = await productService.getOrCreateCategory(_selectedCategory!);
      String? subcategoryId;
      if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
        subcategoryId = await productService.getOrCreateSubcategory(categoryId, _selectedSubcategory!);
      }

      // 3. Map Condition to Database Enum
      String dbCondition = 'good';
      switch (_selectedCondition) {
        case 'New':
        case 'Like New':
          dbCondition = 'like_new';
          break;
        case 'Excellent':
          dbCondition = 'excellent';
          break;
        case 'Good':
          dbCondition = 'good';
          break;
        case 'Fair':
          dbCondition = 'fair';
          break;
      }

      // 4. Upload Images to Supabase Storage (Bucket: 'product_images')
      final imageUrls = await productService.uploadImages(
        _selectedImages,
        authUser.id,
      );

      // 5. Format Description (Appending trade method & offers)
      String finalDescription = _descriptionController.text.trim();
      finalDescription += '\n\n---\nTrade Preferences:\n';
      if (_faceToFace)
        finalDescription += '• Face-to-Face: ${_locationController.text}\n';
      if (_delivery)
        finalDescription +=
            '• Delivery: ${_deliveryMethod == 'official' ? 'Official Delivery' : 'Self-Delivery'}\n';
      if (_openToOffers) finalDescription += '• Open to Offers: Yes';

      // 6. Insert Product into Database
      final productData = <String, dynamic>{
        'title': _nameController.text.trim(),
        'description': finalDescription,
        'price': double.parse(_priceController.text.trim()),
        'category_id': categoryId,
        'seller_id': sellerId,
        'condition': dbCondition,
        'image_urls': imageUrls,
        'status': 'active',
      };
      
      if (subcategoryId != null) {
        productData['subcategory_id'] = subcategoryId;
      }

      await productService.createProduct(productData);

      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Listing published successfully!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      debugPrint('Publish Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('Failed to publish: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _WizardTopBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              onClose: () => Navigator.of(context, rootNavigator: true).pop(),
              onBack: _currentStep > 0 ? _prev : null,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  _Step0Images(
                    images: _selectedImages,
                    onPickGallery: _pickFromGallery,
                    onTakePhoto: _takePhoto,
                    onRemove: (i) =>
                        setState(() => _selectedImages.removeAt(i)),
                  ),
                  _Step1Category(
                    selectedCategory: _selectedCategory,
                    selectedSubcategory: _selectedSubcategory,
                    images: _selectedImages,
                    dbCategories: _categoriesList,
                    dbSubcategories: _subcategoriesList,
                    isLoading: _isLoadingCategories,
                    isLoadingSubcategories: _isLoadingSubcategories,
                    onCategorySelected: (catName) {
                      final cat = _categoriesList.firstWhere((c) => c['name'] == catName);
                      setState(() {
                        _selectedCategory = catName;
                      });
                      _fetchSubcategories(cat['id']);
                    },
                    onSubcategorySelected: (subName) => setState(() {
                      _selectedSubcategory = subName;
                    }),
                    onPickGallery: _pickFromGallery,
                    onRemove: (i) =>
                        setState(() => _selectedImages.removeAt(i)),
                  ),
                  _Step2Details(
                    nameController: _nameController,
                    descriptionController: _descriptionController,
                    priceController: _priceController,
                    selectedCondition: _selectedCondition,
                    openToOffers: _openToOffers,
                    onConditionSelected: (c) =>
                        setState(() => _selectedCondition = c),
                    onOffersChanged: (v) => setState(() => _openToOffers = v),
                  ),
                  _Step3TradeMethod(
                    faceToFace: _faceToFace,
                    delivery: _delivery,
                    locationController: _locationController,
                    deliveryMethod: _deliveryMethod,
                    isLoadingLocation: _isLoadingLocation,
                    onFaceToFaceChanged: (v) => setState(() => _faceToFace = v),
                    onDeliveryChanged: (v) => setState(() => _delivery = v),
                    onDeliveryMethodChanged: (v) =>
                        setState(() => _deliveryMethod = v),
                    onFetchLocation: _fetchGPSLocation,
                    onOpenMap: _openInteractiveMap,
                  ),
                  _Step4Review(
                    images: _selectedImages,
                    category: _selectedCategory,
                    subcategory: _selectedSubcategory,
                    name: _nameController.text,
                    description: _descriptionController.text,
                    condition: _selectedCondition,
                    price: _priceController.text,
                    openToOffers: _openToOffers,
                    faceToFace: _faceToFace,
                    delivery: _delivery,
                    location: _locationController.text,
                    deliveryMethod: _deliveryMethod,
                    isPublishing: _isPublishing,
                    onEdit: (step) => _pageController.animateToPage(
                      step,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                    ),
                    onPublish: _publish,
                  ),
                ],
              ),
            ),
            if (_currentStep < 4)
              _WizardBottomBar(
                canProceed: _canProceed(_currentStep),
                isLastBeforeReview: _currentStep == 3,
                onNext: _next,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _WizardTopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  const _WizardTopBar({
    required this.currentStep,
    required this.totalSteps,
    required this.onClose,
    this.onBack,
  });

  static const List<String> _stepTitles = [
    'Add Photos',
    'Choose Category',
    'Product Details',
    'Trade Method',
    'Review Listing',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = (currentStep + 1) / totalSteps;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      color: const Color(0xFFF6F7FB),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                )
              else
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stepTitles[currentStep],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Step ${currentStep + 1} of $totalSteps',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onBack != null)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: colors.primary.withOpacity(0.12),
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _WizardBottomBar extends StatelessWidget {
  final bool canProceed;
  final bool isLastBeforeReview;
  final VoidCallback onNext;

  const _WizardBottomBar({
    required this.canProceed,
    required this.isLastBeforeReview,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: colors.outline.withOpacity(0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: canProceed ? onNext : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: colors.primary,
          disabledBackgroundColor: colors.primary.withOpacity(0.3),
        ),
        child: Text(
          isLastBeforeReview ? 'Review Listing' : 'Next',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ImageStrip extends StatelessWidget {
  final List<String> images;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final double height;

  const _ImageStrip({
    required this.images,
    required this.onAdd,
    required this.onRemove,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canAdd = images.length < 10;

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          if (canAdd)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: height,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withOpacity(0.08),
                      colors.primary.withOpacity(0.16),
                    ],
                  ),
                  border: Border.all(
                    color: colors.primary.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${images.length}/10',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...List.generate(images.length, (i) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: height,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    image: DecorationImage(
                      image: FileImage(File(images[i])),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (i == 0)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Cover',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: -4,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Steps
// ─────────────────────────────────────────────────────────────────────────────
class _Step0Images extends StatelessWidget {
  final List<String> images;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final void Function(int) onRemove;

  const _Step0Images({
    required this.images,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: onPickGallery,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withOpacity(0.08),
                      colors.primary.withOpacity(0.18),
                    ],
                  ),
                  border: Border.all(
                    color: colors.primary.withOpacity(0.25),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.photo_library_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose from Library',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Up to 10 photos',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: OutlinedButton.icon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'Take a Photo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: BorderSide(color: colors.primary.withOpacity(0.35)),
                foregroundColor: colors.primary,
              ),
            ),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selected Photos',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ImageStrip(
              images: images,
              onAdd: onPickGallery,
              onRemove: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _Step1Category extends StatelessWidget {
  final String? selectedCategory;
  final String? selectedSubcategory;
  final List<String> images;
  final List<Map<String, dynamic>> dbCategories;
  final List<Map<String, dynamic>> dbSubcategories;
  final bool isLoading;
  final bool isLoadingSubcategories;
  final void Function(String catName) onCategorySelected;
  final void Function(String subName) onSubcategorySelected;
  final VoidCallback onPickGallery;
  final void Function(int) onRemove;

  const _Step1Category({
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.images,
    required this.dbCategories,
    required this.dbSubcategories,
    required this.isLoading,
    required this.isLoadingSubcategories,
    required this.onCategorySelected,
    required this.onSubcategorySelected,
    required this.onPickGallery,
    required this.onRemove,
  });

  IconData _getCategoryIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains(RegExp(r'book|text')))
      return Icons.menu_book_rounded;
    if (lowerName.contains(RegExp(r'electronic|device|phone|laptop|pc')))
      return Icons.devices_rounded;
    if (lowerName.contains(RegExp(r'dorm|furniture|bedding')))
      return Icons.bed_rounded;
    if (lowerName.contains(RegExp(r'cloth|shirt|pant|shoe|fashion')))
      return Icons.checkroom_rounded;
    if (lowerName.contains(RegExp(r'sport|gym|basket')))
      return Icons.sports_basketball_rounded;
    if (lowerName.contains(RegExp(r'beaut|makeup|skin')))
      return Icons.face_retouching_natural_rounded;
    if (lowerName.contains(RegExp(r'station|pen|pencil|paper')))
      return Icons.edit_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ImageStrip(
              images: images,
              onAdd: onPickGallery,
              onRemove: onRemove,
              height: 90,
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (dbCategories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('No categories available.'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: dbCategories.map((cat) {
                  final catName = cat['name'] as String;
                  final sel = selectedCategory == catName;
                  return GestureDetector(
                    onTap: () => onCategorySelected(catName),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? colors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel
                              ? colors.primary
                              : colors.outline.withOpacity(0.15),
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: colors.primary.withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(catName),
                            size: 18,
                            color: sel ? Colors.white : colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            catName,
                            style: TextStyle(
                              color: sel ? Colors.white : colors.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (selectedCategory != null) ...[
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Subcategory',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            if (isLoadingSubcategories)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (dbSubcategories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No subcategories available for this category.'),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: dbSubcategories.map((sub) {
                    final subName = sub['name'] as String;
                    final sel = selectedSubcategory == subName;
                    return GestureDetector(
                      onTap: () => onSubcategorySelected(subName),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? colors.secondary : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: sel
                                ? colors.secondary
                                : colors.outline.withOpacity(0.15),
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: colors.secondary.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          subName,
                          style: TextStyle(
                            color: sel ? colors.onSecondary : colors.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Step2Details extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController
  descriptionController; // <-- Added Description Controller
  final TextEditingController priceController;
  final String? selectedCondition;
  final bool openToOffers;
  final void Function(String) onConditionSelected;
  final void Function(bool) onOffersChanged;

  const _Step2Details({
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.selectedCondition,
    required this.openToOffers,
    required this.onConditionSelected,
    required this.onOffersChanged,
  });

  static const List<String> _conditions = [
    'New',
    'Like New',
    'Excellent',
    'Good',
    'Fair',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Product Name'),
          const SizedBox(height: 10),
          _StyledField(
            controller: nameController,
            hint: 'e.g. iPad 9th Gen 64GB',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 24),

          _SectionLabel('Description'), // <-- Added Description UI
          const SizedBox(height: 10),
          _StyledField(
            controller: descriptionController,
            hint: 'Describe your item (flaws, specs, reason for selling)...',
            icon: Icons.notes_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 24),

          _SectionLabel('Condition'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _conditions.map((c) {
              final sel = selectedCondition == c;
              return GestureDetector(
                onTap: () => onConditionSelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? colors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel
                          ? colors.primary
                          : colors.outline.withOpacity(0.15),
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      color: sel ? Colors.white : colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Price (RM)'),
          const SizedBox(height: 10),
          _StyledField(
            controller: priceController,
            hint: '0.00',
            icon: Icons.sell_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            prefixText: 'RM ',
          ),
          const SizedBox(height: 20),
          _OfferToggle(value: openToOffers, onChanged: onOffersChanged),
        ],
      ),
    );
  }
}

class _Step3TradeMethod extends StatelessWidget {
  final bool faceToFace;
  final bool delivery;
  final TextEditingController locationController;
  final String? deliveryMethod;
  final bool isLoadingLocation;
  final void Function(bool) onFaceToFaceChanged;
  final void Function(bool) onDeliveryChanged;
  final void Function(String) onDeliveryMethodChanged;
  final VoidCallback onFetchLocation;
  final VoidCallback onOpenMap;

  const _Step3TradeMethod({
    required this.faceToFace,
    required this.delivery,
    required this.locationController,
    required this.deliveryMethod,
    required this.isLoadingLocation,
    required this.onFaceToFaceChanged,
    required this.onDeliveryChanged,
    required this.onDeliveryMethodChanged,
    required this.onFetchLocation,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select at least one method',
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 16),
          _TradeOptionCard(
            icon: Icons.handshake_rounded,
            title: 'Face-to-Face',
            subtitle: 'Meet the buyer in person at a safe location.',
            selected: faceToFace,
            onTap: () => onFaceToFaceChanged(!faceToFace),
          ),
          if (faceToFace) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _StyledField(
                controller: locationController,
                hint: 'e.g. Campus Library, Ground Floor',
                icon: Icons.location_on_rounded,
                label: 'Meeting Location',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoadingLocation)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.my_location_rounded,
                          color: colors.primary,
                        ),
                        onPressed: onFetchLocation,
                        tooltip: 'Use Current GPS',
                      ),
                    IconButton(
                      icon: Icon(Icons.map_rounded, color: colors.primary),
                      onPressed: onOpenMap,
                      tooltip: 'Select on Map',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _TradeOptionCard(
            icon: Icons.local_shipping_rounded,
            title: 'Delivery',
            subtitle: 'Ship the item to the buyer.',
            selected: delivery,
            onTap: () => onDeliveryChanged(!delivery),
          ),
          if (delivery) ...[
            const SizedBox(height: 12),
            _SectionLabel('Delivery Method'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DeliveryMethodTile(
                    icon: Icons.business_center_rounded,
                    label: 'Official Delivery',
                    selected: deliveryMethod == 'official',
                    onTap: () => onDeliveryMethodChanged('official'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DeliveryMethodTile(
                    icon: Icons.directions_bike_rounded,
                    label: 'Self-Delivery',
                    selected: deliveryMethod == 'self',
                    onTap: () => onDeliveryMethodChanged('self'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Step4Review extends StatelessWidget {
  final List<String> images;
  final String? category;
  final String? subcategory;
  final String name;
  final String description; // <-- Added
  final String? condition;
  final String price;
  final bool openToOffers;
  final bool faceToFace;
  final bool delivery;
  final String location;
  final String? deliveryMethod;
  final bool isPublishing; // <-- Added for loading state
  final void Function(int) onEdit;
  final VoidCallback onPublish;

  const _Step4Review({
    required this.images,
    required this.category,
    required this.subcategory,
    required this.name,
    required this.description,
    required this.condition,
    required this.price,
    required this.openToOffers,
    required this.faceToFace,
    required this.delivery,
    required this.location,
    required this.deliveryMethod,
    required this.isPublishing,
    required this.onEdit,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ImageStrip(
              images: images,
              onAdd: () {},
              onRemove: (_) {},
              height: 100,
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                _ReviewSection(
                  title: 'Photos',
                  value:
                      '${images.length} photo${images.length == 1 ? '' : 's'}',
                  onEdit: () => onEdit(0),
                ),
                _ReviewSection(
                  title: 'Category',
                  value: [
                    category,
                    subcategory,
                  ].where((e) => e != null && e.isNotEmpty).join(' › '),
                  onEdit: () => onEdit(1),
                ),
                _ReviewSection(
                  title: 'Product Name',
                  value: name.isEmpty ? '—' : name,
                  onEdit: () => onEdit(2),
                ),
                _ReviewSection(
                  title: 'Condition',
                  value: condition ?? '—',
                  onEdit: () => onEdit(2),
                ),
                _ReviewSection(
                  title: 'Price',
                  value: price.isEmpty ? '—' : 'RM $price',
                  onEdit: () => onEdit(2),
                ),
                _ReviewSection(
                  title: 'Open to Offers',
                  value: openToOffers ? 'Yes' : 'No',
                  onEdit: () => onEdit(2),
                ),
                _ReviewSection(
                  title: 'Trade Method',
                  value:
                      [
                        if (faceToFace) 'Face-to-Face',
                        if (delivery) 'Delivery',
                      ].join(', ').isEmpty
                      ? '—'
                      : [
                          if (faceToFace) 'Face-to-Face',
                          if (delivery) 'Delivery',
                        ].join(', '),
                  onEdit: () => onEdit(3),
                ),
                if (faceToFace && location.isNotEmpty)
                  _ReviewSection(
                    title: 'Meeting Location',
                    value: location,
                    onEdit: () => onEdit(3),
                  ),
                if (delivery && deliveryMethod != null)
                  _ReviewSection(
                    title: 'Delivery Method',
                    value: deliveryMethod == 'official'
                        ? 'Official Delivery'
                        : 'Self-Delivery',
                    onEdit: () => onEdit(3),
                  ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: isPublishing
                        ? null
                        : onPublish, // Prevent double taps
                    icon: isPublishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.rocket_launch_rounded),
                    label: Text(
                      isPublishing ? 'Publishing...' : 'Complete & Publish',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Helpers
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
                color: selected
                    ? colors.primary
                    : colors.primary.withOpacity(0.10),
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
                  color: selected
                      ? colors.primary
                      : colors.outline.withOpacity(0.3),
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

class _ReviewSection extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onEdit;

  const _ReviewSection({
    required this.title,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
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

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final Widget? suffixIcon;
  final int maxLines; // <-- Added to support description

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
      maxLines: maxLines, // <-- Supports tall text area
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
          color: value
              ? colors.primary.withOpacity(0.14)
              : colors.outline.withOpacity(0.12),
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
                SizedBox(height: 2),
                Text(
                  'Let buyers negotiate the price.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
