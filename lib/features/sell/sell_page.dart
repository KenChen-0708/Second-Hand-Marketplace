import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'MapSelectionScreen.dart';
import '../../services/auth/auth_service.dart';
import '../../services/product/product_service.dart';

Future<String> _convertImageToWebp(String imagePath) async {
  final source = File(imagePath);
  final sourceName = source.uri.pathSegments.isNotEmpty
      ? source.uri.pathSegments.last.split('.').first
      : 'listing_image';
  final outputDirectory = Directory.systemTemp.createTempSync('listing_webp_');
  final outputPath =
      '${outputDirectory.path}${Platform.pathSeparator}'
      '${sourceName}_${DateTime.now().microsecondsSinceEpoch}.webp';
  final compressedImage = await FlutterImageCompress.compressAndGetFile(
    imagePath,
    outputPath,
    quality: 82,
    format: CompressFormat.webp,
    keepExif: false,
  );

  if (compressedImage == null) {
    throw const FormatException('Unable to convert image to WebP');
  }

  return compressedImage.path;
}

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
  final List<String> _selectedImageSources = [];
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategory;
  String? _selectedSubcategory;
  final _nameController = TextEditingController();
  final _descriptionController =
      TextEditingController(); // <-- Added Description
  String? _selectedCondition;
  final _priceController = TextEditingController();
  final List<_VariationGroup> _variations = [];
  final List<_VariantCombination> _variantCombinations = [];

  bool _faceToFace = false;
  bool _delivery = false;
  final _locationController = TextEditingController();
  final _stockController = TextEditingController();
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
    _stockController.addListener(rebuild);
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
    _stockController.dispose();
    _locationController.dispose();
    for (final variation in _variations) {
      variation.dispose();
    }
    for (final combination in _variantCombinations) {
      combination.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    setState(() {
      final group = _VariationGroup();
      group.options.add(_VariationOption());
      _variations.add(group);
      _rebuildVariantCombinations();
    });
  }

  void _addOption(int groupIndex) {
    setState(() {
      _variations[groupIndex].options.add(_VariationOption());
      _rebuildVariantCombinations();
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variations[index].dispose();
      _variations.removeAt(index);
      _rebuildVariantCombinations();
    });
  }

  void _onVariantDimensionsChanged() {
    setState(_rebuildVariantCombinations);
  }

  String _normalizeCombinationPart(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _combinationKey(Map<String, String> attributes) {
    final entries =
        attributes.entries
            .map(
              (entry) =>
                  '${_normalizeCombinationPart(entry.key)}:${_normalizeCombinationPart(entry.value)}',
            )
            .toList()
          ..sort();
    return entries.join('|');
  }

  String _combinationValueKey(Map<String, String> attributes) {
    final values = attributes.values.map(_normalizeCombinationPart).toList()
      ..sort();
    return values.join('|');
  }

  List<Map<String, String>> _cartesianProduct(
    List<MapEntry<String, List<String>>> dimensions,
  ) {
    if (dimensions.isEmpty) return [];

    List<Map<String, String>> combinations = [{}];
    for (final dimension in dimensions) {
      final next = <Map<String, String>>[];
      for (final partial in combinations) {
        for (final value in dimension.value) {
          next.add({...partial, dimension.key: value});
        }
      }
      combinations = next;
    }
    return combinations;
  }

  List<MapEntry<String, List<String>>> _validVariationDimensions() {
    final dimensions = <MapEntry<String, List<String>>>[];
    final seenGroupNames = <String>{};

    for (final group in _variations) {
      final name = group.nameController.text.trim();
      if (name.isEmpty) return [];
      final normalizedName = _normalizeCombinationPart(name);
      if (seenGroupNames.contains(normalizedName)) return [];
      seenGroupNames.add(normalizedName);

      final values = <String>[];
      final seenValues = <String>{};
      for (final option in group.options) {
        final value = option.valueController.text.trim();
        if (value.isEmpty) return [];

        final normalized = _normalizeCombinationPart(value);
        if (seenValues.contains(normalized)) return [];
        seenValues.add(normalized);
        values.add(value);
      }

      if (values.isEmpty) return [];
      dimensions.add(MapEntry(name, values));
    }

    return dimensions;
  }

  void _rebuildVariantCombinations() {
    final oldByKey = {
      for (final combination in _variantCombinations)
        combination.key: combination,
    };
    final oldByValueKey = {
      for (final combination in _variantCombinations)
        _combinationValueKey(combination.attributes): combination,
    };

    final dimensions = _validVariationDimensions();
    final rawCombinations = _cartesianProduct(dimensions);
    final nextCombinations = <_VariantCombination>[];
    final usedKeys = <String>{};
    final defaultPrice = double.tryParse(_priceController.text.trim());

    for (final attributes in rawCombinations) {
      final key = _combinationKey(attributes);
      usedKeys.add(key);
      final existing =
          oldByKey[key] ?? oldByValueKey[_combinationValueKey(attributes)];
      if (existing != null) {
        existing.attributes = attributes;
        nextCombinations.add(existing);
      } else {
        nextCombinations.add(
          _VariantCombination(
            attributes: attributes,
            initialPrice: defaultPrice,
          ),
        );
      }
    }

    for (final combination in _variantCombinations) {
      if (!usedKeys.contains(combination.key)) {
        combination.dispose();
      }
    }

    _variantCombinations
      ..clear()
      ..addAll(nextCombinations);
  }

  bool get _hasDuplicateGroupNames {
    final names = <String>{};
    for (final group in _variations) {
      final name = _normalizeCombinationPart(group.nameController.text);
      if (name.isEmpty) continue;
      if (names.contains(name)) return true;
      names.add(name);
    }
    return false;
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
    // If trying to swipe forward beyond currentStep+1, prevent it.
    // If trying to swipe to currentStep+1 but current step is NOT complete, prevent it.
    if (index > _currentStep) {
      if (!_canProceed(_currentStep) || index > _currentStep + 1) {
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }
    setState(() => _currentStep = index);
  }

  bool get _canProceedStep0 => _selectedImages.isNotEmpty;
  bool get _canProceedStep1 =>
      _selectedCategory != null && _selectedSubcategory != null;
  bool get _canProceedStep2 =>
      _nameController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _selectedCondition != null &&
      (_variations.isEmpty
          ? _priceController.text.trim().isNotEmpty &&
                (int.tryParse(_stockController.text.trim()) ?? 0) >= 1
          : _variations.every((group) => group.isValid) &&
                !_hasDuplicateGroupNames &&
                _variantCombinations.isNotEmpty &&
                _variantCombinations.every((combo) => combo.isValid));

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
  Future<void> _addImage(String imagePath) async {
    if (_selectedImages.length >= 10 ||
        _selectedImageSources.contains(imagePath)) {
      return;
    }

    final webpPath = await _convertImageToWebp(imagePath);
    if (!mounted ||
        _selectedImages.length >= 10 ||
        _selectedImageSources.contains(imagePath)) {
      return;
    }

    setState(() {
      _selectedImages.add(webpPath);
      _selectedImageSources.add(imagePath);
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedImageSources.removeAt(index);
    });
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo != null) await _addImage(photo.path);
    } catch (e) {
      debugPrint("Error taking photo: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);
      if (images.isNotEmpty) {
        for (final image in images) {
          if (_selectedImages.length >= 10) {
            break;
          }
          await _addImage(image.path);
        }
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
      final categoryId = await productService.getOrCreateCategory(
        _selectedCategory!,
      );
      String? subcategoryId;
      if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
        subcategoryId = await productService.getOrCreateSubcategory(
          categoryId,
          _selectedSubcategory!,
        );
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

      // 5. Upload Images to Supabase Storage (Bucket: 'product_images')
      final imageUrls = await productService.uploadImages(
        _selectedImages,
        authUser.id,
      );

      // 6. Determine Trade Preference (Multi-select array)
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

      // 8. Insert Product into Database
      double basePrice = double.tryParse(_priceController.text.trim()) ?? 0;
      int totalStock = int.tryParse(_stockController.text.trim()) ?? 0;

      if (_variations.isNotEmpty) {
        // Calculate min price and total stock from variants
        double minPrice = double.infinity;
        int sumStock = 0;
        for (final combination in _variantCombinations) {
          final p = double.tryParse(combination.priceController.text.trim());
          if (p != null && p < minPrice) minPrice = p;

          final q =
              int.tryParse(combination.quantityController.text.trim()) ?? 0;
          sumStock += q;
        }

        if (minPrice != double.infinity) basePrice = minPrice;
        totalStock = sumStock;
      }

      final productData = <String, dynamic>{
        'title': _nameController.text.trim(),
        'description': finalDescription,
        'base_price': basePrice,
        'total_stock': totalStock,
        'category_id': categoryId,
        'seller_id': sellerId,
        'condition': dbCondition,
        'image_urls': imageUrls,
        'trade_preference': tradePreferences,
        'status': 'active',
      };

      if (subcategoryId != null) {
        productData['subcategory_id'] = subcategoryId;
      }

      final productId = await productService.createProduct(productData);

      // 8b. Create Variants from Groups
      final List<Map<String, dynamic>> variantRows = [];
      for (final combination in _variantCombinations) {
        variantRows.add({
          'product_id': productId,
          'sku': combination.skuController.text.trim().isEmpty
              ? null
              : combination.skuController.text.trim(),
          'quantity':
              int.tryParse(combination.quantityController.text.trim()) ?? 0,
          'price':
              double.tryParse(combination.priceController.text.trim()) ?? 0,
          'attributes': combination.attributes.entries
              .map(
                (entry) => {
                  'attribute_name': entry.key,
                  'attribute_value': entry.value,
                },
              )
              .toList(),
        });
      }

      if (variantRows.isNotEmpty) {
        await productService.createProductVariations(variantRows);
      }

      // 9. Insert Meetup Location into product_meetup_locations table
      if (_faceToFace && _locationController.text.isNotEmpty) {
        await productService.createMeetupLocation({
          'product_id': productId,
          'location_name': _locationController.text.trim(),
          'address': _locationController.text.trim(),
          'is_default': true,
        });
      }

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
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  _Step0Images(
                    images: _selectedImages,
                    onPickGallery: _pickFromGallery,
                    onTakePhoto: _takePhoto,
                    onRemove: _removeImage,
                  ),
                  _Step1Category(
                    selectedCategory: _selectedCategory,
                    selectedSubcategory: _selectedSubcategory,
                    dbCategories: _categoriesList,
                    dbSubcategories: _subcategoriesList,
                    isLoading: _isLoadingCategories,
                    isLoadingSubcategories: _isLoadingSubcategories,
                    onCategorySelected: (catName) {
                      final cat = _categoriesList.firstWhere(
                        (c) => c['name'] == catName,
                      );
                      setState(() {
                        _selectedCategory = catName;
                      });
                      _fetchSubcategories(cat['id']);
                    },
                    onSubcategorySelected: (subName) => setState(() {
                      _selectedSubcategory = subName;
                    }),
                  ),
                  _Step2Details(
                    nameController: _nameController,
                    descriptionController: _descriptionController,
                    priceController: _priceController,
                    variations: _variations,
                    variantCombinations: _variantCombinations,
                    selectedCondition: _selectedCondition,
                    onConditionSelected: (c) =>
                        setState(() => _selectedCondition = c),
                    onAddVariant: _addVariant,
                    onRemoveVariant: _removeVariant,
                    onAddOption: _addOption,
                    onVariantChanged: _onVariantDimensionsChanged,
                    onCombinationChanged: () => setState(() {}),
                    stockController: _stockController,
                  ),
                  _Step3TradeMethod(
                    faceToFace: _faceToFace,
                    delivery: _delivery,
                    locationController: _locationController,
                    deliveryMethod: _deliveryMethod,
                    isLoadingLocation: _isLoadingLocation,
                    onFaceToFaceChanged: (v) => setState(() => _faceToFace = v),
                    onDeliveryChanged: (v) => setState(() {
                      _delivery = v;
                      if (v && _deliveryMethod == null) {
                        _deliveryMethod = 'official';
                      }
                    }),
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
                    stock: _stockController.text,
                    variations: _variations,
                    variantCombinations: _variantCombinations,
                    faceToFace: _faceToFace,
                    delivery: _delivery,
                    location: _locationController.text,
                    deliveryMethod: _deliveryMethod,
                    isPublishing: _isPublishing,
                    onPickGallery: _pickFromGallery,
                    onTakePhoto: _takePhoto,
                    onRemoveImage: (idx) {
                      if (_selectedImages.length > 1) {
                        _removeImage(idx);
                      }
                    },
                    onUpdateField: (field, value) {
                      setState(() {
                        switch (field) {
                          case 'name':
                            _nameController.text = value;
                            break;
                          case 'description':
                            _descriptionController.text = value;
                            break;
                          case 'price':
                            _priceController.text = value;
                            break;
                          case 'stock':
                            _stockController.text = value;
                            break;
                          case 'condition':
                            _selectedCondition = value;
                            break;
                        }
                      });
                    },
                    onUpdateVariations: _onVariantDimensionsChanged,
                    onUpdateVariantCombinations: () => setState(() {}),
                    onUpdateCategory: (cat, sub) {
                      setState(() {
                        _selectedCategory = cat;
                        _selectedSubcategory = sub;
                      });
                    },
                    onUpdateTradeMethod: (f2f, del, loc, delMethod) {
                      setState(() {
                        _faceToFace = f2f;
                        _delivery = del;
                        _locationController.text = loc;
                        _deliveryMethod = delMethod;
                      });
                    },
                    dbCategories: _categoriesList,
                    fetchSubcategories: (catId) async {
                      final productService = ProductService();
                      return await productService.fetchSubcategories(catId);
                    },
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
  final List<Map<String, dynamic>> dbCategories;
  final List<Map<String, dynamic>> dbSubcategories;
  final bool isLoading;
  final bool isLoadingSubcategories;
  final void Function(String catName) onCategorySelected;
  final void Function(String subName) onSubcategorySelected;

  const _Step1Category({
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.dbCategories,
    required this.dbSubcategories,
    required this.isLoading,
    required this.isLoadingSubcategories,
    required this.onCategorySelected,
    required this.onSubcategorySelected,
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
          const SizedBox(height: 24),
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
  final TextEditingController stockController;
  final List<_VariationGroup> variations;
  final List<_VariantCombination> variantCombinations;

  final String? selectedCondition;
  final void Function(String) onConditionSelected;
  final VoidCallback onAddVariant;
  final void Function(int) onRemoveVariant;
  final void Function(int) onAddOption;

  final VoidCallback onVariantChanged;
  final VoidCallback onCombinationChanged;

  const _Step2Details({
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.variations,
    required this.variantCombinations,
    required this.selectedCondition,
    required this.onConditionSelected,
    required this.onAddVariant,
    required this.onRemoveVariant,
    required this.onAddOption,
    required this.onVariantChanged,
    required this.onCombinationChanged,
    required this.stockController,
  });

  static const List<String> _conditions = [
    'New',
    'Like New',
    'Excellent',
    'Good',
    'Fair',
  ];

  bool get _hasDuplicateGroupNames {
    final names = <String>{};
    for (final group in variations) {
      final name = group.nameController.text.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (name.isEmpty) continue;
      if (names.contains(name)) return true;
      names.add(name);
    }
    return false;
  }

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
            hint: 'product name',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 24),

          _SectionLabel('Description'),
          const SizedBox(height: 10),
          _StyledField(
            controller: descriptionController,
            hint: 'describe your item',
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
          if (variations.isEmpty) ...[
            _SectionLabel('Price (RM)'),
            const SizedBox(height: 10),
            _StyledField(
              controller: priceController,
              hint: '0.00',
              icon: Icons.sell_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              prefixText: 'RM ',
            ),
            const SizedBox(height: 24),
            _SectionLabel('Available Stock'),
            const SizedBox(height: 10),
            _StyledField(
              controller: stockController,
              hint: '0',
              icon: Icons.inventory_2_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: _SectionLabel('Product Variants')),
              TextButton.icon(
                onPressed: onAddVariant,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Variant'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Define variation types like Color and Size. Price and stock are set on each generated combination.',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 12),
          if (variations.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outline.withOpacity(0.12)),
              ),
              child: Text(
                'No variants added. The listing will be published without variant-level stock.',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withOpacity(0.65),
                ),
              ),
            )
          else
            Column(
              children: List.generate(
                variations.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VariationGroupEditor(
                    group: variations[index],
                    index: index,
                    onAddOption: () => onAddOption(index),
                    onChanged: onVariantChanged,
                    onRemove: () => onRemoveVariant(index),
                  ),
                ),
              ),
            ),
          if (_hasDuplicateGroupNames)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Variation type names must be unique.',
                style: TextStyle(
                  color: colors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (variations.isNotEmpty) ...[
            const SizedBox(height: 24),
            _GeneratedVariantList(
              combinations: variantCombinations,
              onChanged: onCombinationChanged,
            ),
          ],
          if (variations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: onAddVariant,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Another Variant Type'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
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
  final String description;
  final String? condition;
  final String price;
  final String stock;
  final List<_VariationGroup> variations;
  final List<_VariantCombination> variantCombinations;
  final bool faceToFace;
  final bool delivery;
  final String location;
  final String? deliveryMethod;
  final bool isPublishing;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final void Function(int) onRemoveImage;
  final void Function(String field, String value) onUpdateField;
  final VoidCallback onUpdateVariations;
  final VoidCallback onUpdateVariantCombinations;
  final void Function(String cat, String sub) onUpdateCategory;
  final void Function(bool f2f, bool del, String loc, String? delMethod)
  onUpdateTradeMethod;
  final List<Map<String, dynamic>> dbCategories;
  final Future<List<Map<String, dynamic>>> Function(String catId)
  fetchSubcategories;
  final VoidCallback onPublish;

  const _Step4Review({
    required this.images,
    required this.category,
    required this.subcategory,
    required this.name,
    required this.description,
    required this.condition,
    required this.price,
    required this.stock,
    required this.variations,
    required this.variantCombinations,
    required this.faceToFace,
    required this.delivery,
    required this.location,
    required this.deliveryMethod,
    required this.isPublishing,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onRemoveImage,
    required this.onUpdateField,
    required this.onUpdateVariations,
    required this.onUpdateVariantCombinations,
    required this.onUpdateCategory,
    required this.onUpdateTradeMethod,
    required this.dbCategories,
    required this.fetchSubcategories,
    required this.onPublish,
  });

  void _showModernModal(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, _) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[50],
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: SingleChildScrollView(child: child),
              ),
              contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            ),
          ),
        );
      },
    );
  }

  void _showEditModal(
    BuildContext context, {
    required String title,
    required String initialValue,
    required void Function(String) onSave,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);
    _showModernModal(
      context,
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: maxLines,
              keyboardType: isNumber
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                hintText: 'Enter $title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryModal(BuildContext context) {
    _showModernModal(
      context,
      title: 'Change Category',
      child: _CategoryEditContent(
        initialCategory: category,
        initialSubcategory: subcategory,
        dbCategories: dbCategories,
        fetchSubcategories: fetchSubcategories,
        onSave: (cat, sub) {
          onUpdateCategory(cat, sub);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showConditionModal(BuildContext context) {
    final conditions = ['New', 'Like New', 'Excellent', 'Good', 'Fair'];
    _showModernModal(
      context,
      title: 'Change Condition',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Column(
          children: conditions.map((c) {
            final sel = condition == c;
            return ListTile(
              leading: Icon(
                sel
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: sel
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              title: Text(
                c,
                style: TextStyle(
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () {
                onUpdateField('condition', c);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTradeMethodModal(BuildContext context) {
    _showModernModal(
      context,
      title: 'Trade Preferences',
      child: _TradeMethodEditContent(
        initialF2F: faceToFace,
        initialDel: delivery,
        initialLoc: location,
        initialDelMethod: deliveryMethod,
        onSave: (f2f, del, loc, dm) {
          onUpdateTradeMethod(f2f, del, loc, dm);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showImagePickerChoice(BuildContext context) {
    _showModernModal(
      context,
      title: 'Add Photo',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Row(
          children: [
            Expanded(
              child: _PickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  onPickGallery();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _PickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  onTakePhoto();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _ImageStrip(
            images: images,
            onAdd: () => _showImagePickerChoice(context),
            onRemove: (idx) {
              if (images.length > 1) onRemoveImage(idx);
            },
            height: 110,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                _ReviewSection(
                  title: 'Category',
                  value: [
                    category,
                    subcategory,
                  ].where((e) => e != null && e.isNotEmpty).join(' › '),
                  onEdit: () => _showCategoryModal(context),
                ),
                _ReviewSection(
                  title: 'Product Name',
                  value: name.isEmpty ? '—' : name,
                  onEdit: () => _showEditModal(
                    context,
                    title: 'Edit Name',
                    initialValue: name,
                    onSave: (v) => onUpdateField('name', v),
                  ),
                ),
                _ReviewSection(
                  title: 'Description',
                  value: description.isEmpty ? '—' : description,
                  maxLines: 2,
                  onEdit: () => _showEditModal(
                    context,
                    title: 'Edit Description',
                    initialValue: description,
                    maxLines: 5,
                    onSave: (v) => onUpdateField('description', v),
                  ),
                ),
                _ReviewSection(
                  title: 'Condition',
                  value: condition ?? '—',
                  onEdit: () => _showConditionModal(context),
                ),
                if (variations.isEmpty) ...[
                  _ReviewSection(
                    title: 'Price',
                    value: price.isEmpty ? '—' : 'RM $price',
                    onEdit: () => _showEditModal(
                      context,
                      title: 'Edit Price',
                      initialValue: price,
                      isNumber: true,
                      onSave: (v) => onUpdateField('price', v),
                    ),
                  ),
                  _ReviewSection(
                    title: 'Stock',
                    value: stock.isEmpty ? '0' : stock,
                    onEdit: () => _showEditModal(
                      context,
                      title: 'Edit Stock',
                      initialValue: stock,
                      isNumber: true,
                      onSave: (v) => onUpdateField('stock', v),
                    ),
                  ),
                ],
                if (variations.isNotEmpty)
                  _VariantReviewList(
                    combinations: variantCombinations,
                    onUpdate: onUpdateVariantCombinations,
                  ),
                _ReviewSection(
                  title: 'Trade Method',
                  value: () {
                    List<String> methods = [];
                    if (faceToFace) methods.add('Face-to-Face');
                    if (delivery) methods.add('Delivery');
                    return methods.isEmpty ? '—' : methods.join(' & ');
                  }(),
                  onEdit: () => _showTradeMethodModal(context),
                ),
                if (faceToFace && location.isNotEmpty)
                  _ReviewSection(
                    title: 'Meeting Location',
                    value: location,
                    // location is updated via TradeMethod modal
                    onEdit: () => _showTradeMethodModal(context),
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
                    onPressed: isPublishing ? null : onPublish,
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

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.primary.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.primary, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _CategoryEditContent extends StatefulWidget {
  final String? initialCategory;
  final String? initialSubcategory;
  final List<Map<String, dynamic>> dbCategories;
  final Future<List<Map<String, dynamic>>> Function(String catId)
  fetchSubcategories;
  final void Function(String cat, String sub) onSave;

  const _CategoryEditContent({
    required this.initialCategory,
    required this.initialSubcategory,
    required this.dbCategories,
    required this.fetchSubcategories,
    required this.onSave,
  });

  @override
  State<_CategoryEditContent> createState() => _CategoryEditContentState();
}

class _CategoryEditContentState extends State<_CategoryEditContent> {
  String? _tempCat;
  String? _tempSub;
  List<Map<String, dynamic>> _tempSubList = [];
  bool _isLoadingSubs = false;

  @override
  void initState() {
    super.initState();
    _tempCat = widget.initialCategory;
    _tempSub = widget.initialSubcategory;
    if (_tempCat != null) {
      final cat = widget.dbCategories.firstWhere((c) => c['name'] == _tempCat);
      _loadSubcategories(cat['id']);
    }
  }

  Future<void> _loadSubcategories(String catId) async {
    setState(() => _isLoadingSubs = true);
    final subs = await widget.fetchSubcategories(catId);
    setState(() {
      _tempSubList = subs;
      _isLoadingSubs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.dbCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = widget.dbCategories[index];
              final name = cat['name'] as String;
              final sel = _tempCat == name;
              return ChoiceChip(
                label: Text(name),
                selected: sel,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _tempCat = name;
                      _tempSub = null;
                      _tempSubList = [];
                    });
                    _loadSubcategories(cat['id']);
                  }
                },
              );
            },
          ),
        ),
        const Divider(),
        if (_isLoadingSubs)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else if (_tempSubList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              children: _tempSubList.map((sub) {
                final name = sub['name'] as String;
                final sel = _tempSub == name;
                return ChoiceChip(
                  label: Text(name),
                  selected: sel,
                  onSelected: (val) {
                    if (val) setState(() => _tempSub = name);
                  },
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FilledButton(
            onPressed: (_tempCat != null && _tempSub != null)
                ? () => widget.onSave(_tempCat!, _tempSub!)
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }
}

class _TradeMethodEditContent extends StatefulWidget {
  final bool initialF2F;
  final bool initialDel;
  final String initialLoc;
  final String? initialDelMethod;
  final void Function(bool f2f, bool del, String loc, String? dm) onSave;

  const _TradeMethodEditContent({
    required this.initialF2F,
    required this.initialDel,
    required this.initialLoc,
    required this.initialDelMethod,
    required this.onSave,
  });

  @override
  State<_TradeMethodEditContent> createState() =>
      _TradeMethodEditContentState();
}

class _TradeMethodEditContentState extends State<_TradeMethodEditContent> {
  late bool _f2f;
  late bool _del;
  late TextEditingController _locController;
  String? _delMethod;

  @override
  void initState() {
    super.initState();
    _f2f = widget.initialF2F;
    _del = widget.initialDel;
    _locController = TextEditingController(text: widget.initialLoc);
    _delMethod = widget.initialDelMethod;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Face-to-Face'),
            value: _f2f,
            onChanged: (v) => setState(() => _f2f = v),
          ),
          if (_f2f)
            TextField(
              controller: _locController,
              decoration: const InputDecoration(labelText: 'Meeting Location'),
            ),
          SwitchListTile(
            title: const Text('Delivery'),
            value: _del,
            onChanged: (v) => setState(() => _del = v),
          ),
          if (_del)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Official'),
                    selected: _delMethod == 'official',
                    onSelected: (v) => setState(() => _delMethod = 'official'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Self'),
                    selected: _delMethod == 'self',
                    onSelected: (v) => setState(() => _delMethod = 'self'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_f2f || _del)
                ? () =>
                      widget.onSave(_f2f, _del, _locController.text, _delMethod)
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Update Preferences'),
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
  final VoidCallback? onEdit;
  final int maxLines;

  const _ReviewSection({
    required this.title,
    required this.value,
    this.onEdit,
    this.maxLines = 1,
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
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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

class _VariationGroupEditor extends StatelessWidget {
  const _VariationGroupEditor({
    required this.group,
    required this.index,
    required this.onAddOption,
    required this.onChanged,
    required this.onRemove,
  });

  final _VariationGroup group;
  final int index;
  final VoidCallback onAddOption;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Variation Type ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                tooltip: 'Remove type',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StyledField(
            controller: group.nameController,
            hint: 'e.g. Color, Size, Storage',
            icon: Icons.category_rounded,
            label: 'Variation Type Name',
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Attributes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (group.options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No attributes added yet.',
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...List.generate(group.options.length, (optIndex) {
              final opt = group.options[optIndex];
              return _VariationOptionCard(
                option: opt,
                showRemove: group.options.length > 1,
                onRemove: () {
                  group.options[optIndex].dispose();
                  group.options.removeAt(optIndex);
                  onChanged();
                },
                onChanged: onChanged,
              );
            }),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onAddOption,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              'Add Another Attribute',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: colors.primary.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (!group.isValid && group.nameController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                group.hasDuplicateValues
                    ? 'Option values must be unique within this variation type.'
                    : 'Please add at least one valid attribute.',
                style: TextStyle(
                  color: colors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VariationOptionCard extends StatelessWidget {
  final _VariationOption option;
  final bool showRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _VariationOptionCard({
    required this.option,
    required this.showRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StyledField(
                  controller: option.valueController,
                  label: 'Value',
                  hint: 'e.g. Red, XL, 128GB',
                  icon: Icons.label_important_outline_rounded,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              if (showRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariationGroup {
  final TextEditingController nameController;
  final List<_VariationOption> options;

  _VariationGroup({String name = ''})
    : nameController = TextEditingController(text: name),
      options = [];

  bool get isValid =>
      nameController.text.trim().isNotEmpty &&
      options.isNotEmpty &&
      options.every((o) => o.isValid) &&
      !hasDuplicateValues;

  bool get hasDuplicateValues {
    final values = <String>{};
    for (final option in options) {
      final value = option.valueController.text.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (value.isEmpty) continue;
      if (values.contains(value)) return true;
      values.add(value);
    }
    return false;
  }

  void dispose() {
    nameController.dispose();
    for (var opt in options) {
      opt.dispose();
    }
  }
}

class _VariationOption {
  final TextEditingController valueController;

  _VariationOption() : valueController = TextEditingController();

  bool get isValid => valueController.text.trim().isNotEmpty;

  void dispose() {
    valueController.dispose();
  }
}

class _VariantCombination {
  Map<String, String> attributes;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController skuController;

  _VariantCombination({required this.attributes, double? initialPrice})
    : priceController = TextEditingController(
        text: initialPrice?.toStringAsFixed(2) ?? '',
      ),
      quantityController = TextEditingController(text: '1'),
      skuController = TextEditingController();

  String get key {
    final entries =
        attributes.entries
            .map(
              (entry) =>
                  '${entry.key.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}:${entry.value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}',
            )
            .toList()
          ..sort();
    return entries.join('|');
  }

  String get label => attributes.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .join(' | ');

  bool get isValid {
    final quantity = int.tryParse(quantityController.text.trim());
    final price = double.tryParse(priceController.text.trim());
    return attributes.isNotEmpty &&
        quantity != null &&
        quantity >= 1 &&
        price != null &&
        price > 0;
  }

  void dispose() {
    priceController.dispose();
    quantityController.dispose();
    skuController.dispose();
  }
}

class _GeneratedVariantList extends StatefulWidget {
  final List<_VariantCombination> combinations;
  final VoidCallback onChanged;

  const _GeneratedVariantList({
    required this.combinations,
    required this.onChanged,
  });

  @override
  State<_GeneratedVariantList> createState() => _GeneratedVariantListState();
}

class _GeneratedVariantListState extends State<_GeneratedVariantList> {
  final _bulkPriceController = TextEditingController();
  final _bulkStockController = TextEditingController();

  @override
  void dispose() {
    _bulkPriceController.dispose();
    _bulkStockController.dispose();
    super.dispose();
  }

  void _applyToAll() {
    final price = _bulkPriceController.text.trim();
    final stock = _bulkStockController.text.trim();

    for (final combination in widget.combinations) {
      if (price.isNotEmpty) {
        combination.priceController.text = price;
      }
      if (stock.isNotEmpty) {
        combination.quantityController.text = stock;
      }
    }

    widget.onChanged();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Generated Variants'),
        const SizedBox(height: 8),
        Text(
          'Each row is one sellable SKU combination.',
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurface.withOpacity(0.55),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.combinations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outline.withOpacity(0.12)),
            ),
            child: Text(
              'Complete every variation type and option value to generate combinations.',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withOpacity(0.65),
              ),
            ),
          )
        else ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.primary.withOpacity(0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Apply to all variants',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StyledField(
                        controller: _bulkPriceController,
                        label: 'Price',
                        hint: '0.00',
                        icon: Icons.sell_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        prefixText: 'RM ',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StyledField(
                        controller: _bulkStockController,
                        label: 'Stock',
                        hint: '0',
                        icon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applyToAll,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text(
                    'Apply to All',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...widget.combinations.map(
            (combination) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outline.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    combination.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StyledField(
                          controller: combination.priceController,
                          label: 'Price',
                          hint: '0.00',
                          icon: Icons.sell_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          prefixText: 'RM ',
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StyledField(
                          controller: combination.quantityController,
                          label: 'Stock',
                          hint: '0',
                          icon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StyledField(
                    controller: combination.skuController,
                    label: 'SKU (optional)',
                    hint: 'e.g. SHIRT-RED-L',
                    icon: Icons.qr_code_2_rounded,
                    onChanged: (_) => widget.onChanged(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
  final ValueChanged<String>? onChanged;

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
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
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
          borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _VariantReviewList extends StatelessWidget {
  final List<_VariantCombination> combinations;
  final VoidCallback onUpdate;

  const _VariantReviewList({
    required this.combinations,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Variants',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ),
        ...combinations.map((combination) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outline.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        combination.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _showVariantEditModal(context, combination),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'RM ${combination.priceController.text}',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${combination.quantityController.text} qty',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                if (combination.skuController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'SKU: ${combination.skuController.text.trim()}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showVariantEditModal(
    BuildContext context,
    _VariantCombination combination,
  ) {
    final priceController = TextEditingController(
      text: combination.priceController.text,
    );
    final qtyController = TextEditingController(
      text: combination.quantityController.text,
    );
    final skuController = TextEditingController(
      text: combination.skuController.text,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Edit Variant',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      combination.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Price (RM)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU (optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    combination.priceController.text = priceController.text;
                    combination.quantityController.text = qtyController.text;
                    combination.skuController.text = skuController.text;
                    onUpdate();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
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
