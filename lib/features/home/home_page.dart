import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/mock_data.dart';
import '../../shared/utils/camera_capture_helper.dart';
import '../../shared/utils/currency_helper.dart';
import '../../shared/utils/image_helper.dart';
import '../../shared/utils/product_display_helper.dart';
import '../../state/state.dart';
import 'product_listing_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- Search State ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoadingProducts = true;
  String? _productLoadError;
  ProductState? _productState;

  // --- Filter State ---
  RangeValues _priceRange = const RangeValues(0, 2000);
  final Set<String> _selectedConditions = {};

  final List<String> _conditions = [
    'New',
    'Like New',
    'Excellent',
    'Good',
    'Acceptable',
  ];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
      _loadChatConversations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProductState = context.read<ProductState>();
    if (_productState != newProductState) {
      _productState?.removeListener(_onProductStateChanged);
      _productState = newProductState;
      _productState?.addListener(_onProductStateChanged);
    }
  }

  void _onProductStateChanged() {
    if (mounted && _productState != null) {
      setState(() {
        _allProducts = _visibleMarketplaceProducts(_productState!.items);
        _applyAllFilters();
      });
    }
  }

  @override
  void dispose() {
    _productState?.removeListener(_onProductStateChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // --- Search Logic ---
  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productLoadError = null;
    });

    try {
      final products = await context.read<ProductState>().fetchProducts();
      if (!mounted) {
        return;
      }

      setState(() {
        _allProducts = _visibleMarketplaceProducts(products);
        _applyAllFilters();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _allProducts = [];
        _filteredProducts = [];
        _productLoadError =
            'Unable to load products right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  Future<void> _loadChatConversations() async {
    try {
      await context.read<ChatConversationState>().fetchUserConversations();
    } catch (_) {
      // Keep the home page usable even if messages fail to load.
    }
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return 'Uncategorized';
    final category = mockCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => mockCategories[0],
    );
    return category.name;
  }

  void _onSearchSubmitted(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _applyAllFilters();
      } else {
        final lowerQuery = query.trim().toLowerCase();
        _filteredProducts = _allProducts.where((p) {
          return p.title.toLowerCase().contains(lowerQuery) ||
              _getCategoryName(p.categoryId).toLowerCase().contains(lowerQuery) ||
              p.condition.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
    print('[Search] Query: "$query" → ${_filteredProducts.length} result(s)');
  }

  // --- Filter Reset Logic ---

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 2000);
      _selectedConditions.clear();
      _selectedCategories.clear();
      _selectedSort = 'Relevance';
      _applyAllFilters();
    });
  }

  // --- Filter State extras ---
  String _selectedSort = 'Relevance';
  final Set<String> _selectedCategories = {};

  final List<String> _sortOptions = [
    'Relevance',
    'Price: Low to High',
    'Price: High to Low',
    'Newest First',
  ];

  final List<Map<String, dynamic>> _categoryOptions = [
    {'icon': Icons.menu_book_rounded, 'label': 'Textbooks'},
    {'icon': Icons.laptop_mac_rounded, 'label': 'Electronics'},
    {'icon': Icons.chair_rounded, 'label': 'Dorm Gear'},
    {'icon': Icons.sports_basketball_rounded, 'label': 'Sports'},
    {'icon': Icons.checkroom_rounded, 'label': 'Clothing'},
  ];

  bool get _hasActiveFilters =>
      _selectedConditions.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _selectedSort != 'Relevance' ||
      _priceRange != const RangeValues(0, 2000);

  // --- Filter Modal ---
  void _showFilterModal() {
    // Temp copies — committed only on Apply
    RangeValues tempPrice = _priceRange;
    Set<String> tempConditions = Set.from(_selectedConditions);
    Set<String> tempCategories = Set.from(_selectedCategories); String tempSort = _selectedSort;

    // useRootNavigator: true → sheet covers the bottom nav bar
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            final tt = Theme.of(ctx).textTheme;

            // ── section label ──────────────────────────────────
            Widget sectionLabel(String text) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                text,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: cs.onSurface,
                ),
              ),
            );

            // ── divider ────────────────────────────────────────
            Widget divider() => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: cs.outlineVariant, height: 1),
            );

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ── drag handle + header ─────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: cs.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: cs.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Filters',
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                // Active filter count badge
                                if (tempConditions.isNotEmpty ||
                                    tempCategories.isNotEmpty ||
                                    tempSort != 'Relevance' ||
                                    tempPrice != const RangeValues(0, 2000))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${(tempConditions.isNotEmpty ? 1 : 0) + (tempCategories.isNotEmpty ? 1 : 0) + (tempSort != 'Relevance' ? 1 : 0) + (tempPrice != const RangeValues(0, 600) ? 1 : 0)} active',
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () => setModalState(() {
                                    tempPrice = const RangeValues(0, 2000);
                                    tempConditions.clear();
                                    tempCategories.clear();
                                    tempSort = 'Relevance';
                                  }),
                                  child: Text(
                                    'Reset all',
                                    style: TextStyle(
                                      color: cs.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Divider(color: cs.outlineVariant, height: 1),

                      // ── scrollable body ──────────────────────
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          children: [
                            // ── SORT BY ───────────────────────
                            sectionLabel('Sort By'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sortOptions.map((opt) {
                                final sel = tempSort == opt;
                                return ChoiceChip(
                                  label: Text(opt),
                                  selected: sel,
                                  onSelected: (_) =>
                                      setModalState(() => tempSort = opt),
                                  selectedColor: cs.primary,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color: sel ? Colors.white : cs.onSurface,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: sel
                                          ? cs.primary
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  showCheckmark: false,
                                );
                              }).toList(),
                            ),

                            divider(),

                            // ── CATEGORY ─────────────────────
                            sectionLabel('Category'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categoryOptions.map((cat) {
                                final label = cat['label'] as String;
                                final icon = cat['icon'] as IconData;
                                final sel = tempCategories.contains(label);
                                return FilterChip(
                                  avatar: Icon(
                                    icon,
                                    size: 16,
                                    color: sel
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  label: Text(label),
                                  selected: sel,
                                  onSelected: (v) => setModalState(() {
                                    if (v) {
                                      tempCategories.add(label);
                                    } else {
                                      tempCategories.remove(label);
                                    }
                                  }),
                                  selectedColor: cs.primaryContainer,
                                  checkmarkColor: cs.primary,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color: sel ? cs.primary : cs.onSurface,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: sel
                                          ? cs.primary
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  showCheckmark: false,
                                );
                              }).toList(),
                            ),

                            divider(),

                            // ── PRICE RANGE ───────────────────
                            sectionLabel('Price Range'),
                            Row(
                              children: [
                                _pricePill(ctx, 'RM ${tempPrice.start.toInt()}'),
                                const Spacer(),
                                Text(
                                  'to',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                _pricePill(ctx, 'RM ${tempPrice.end.toInt()}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: cs.primary,
                                inactiveTrackColor: cs.primaryContainer,
                                thumbColor: cs.primary,
                                overlayColor: cs.primary.withValues(
                                  alpha: 0.12,
                                ),
                                trackHeight: 5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10,
                                ),
                              ),
                              child: RangeSlider(
                                values: tempPrice,
                                min: 0,
                                max: 2000,
                                divisions: 200,
                                onChanged: (v) =>
                                    setModalState(() => tempPrice = v),
                              ),
                            ),
                            // Quick price presets
                            Wrap(
                              spacing: 8,
                              children: [
                                _pricePreset(
                                  ctx,
                                  'Under RM 100',
                                  const RangeValues(0, 100),
                                  tempPrice,
                                  (v) => setModalState(() => tempPrice = v),
                                ),
                                _pricePreset(
                                  ctx,
                                  '\$100–\$500',
                                  const RangeValues(100, 500),
                                  tempPrice,
                                  (v) => setModalState(() => tempPrice = v),
                                ),
                                _pricePreset(
                                  ctx,
                                  '\$500–\$1000',
                                  const RangeValues(500, 1000),
                                  tempPrice,
                                  (v) => setModalState(() => tempPrice = v),
                                ),
                                _pricePreset(
                                  ctx,
                                  'Any',
                                  const RangeValues(0, 2000),
                                  tempPrice,
                                  (v) => setModalState(() => tempPrice = v),
                                ),
                              ],
                            ),

                            divider(),

                            // ── CONDITION ─────────────────────
                            sectionLabel('Condition'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _conditions.map((c) {
                                final sel = tempConditions.contains(c);
                                return FilterChip(
                                  label: Text(c),
                                  selected: sel,
                                  onSelected: (v) => setModalState(() {
                                    if (v) {
                                      tempConditions.add(c);
                                    } else {
                                      tempConditions.remove(c);
                                    }
                                  }),
                                  selectedColor: cs.primaryContainer,
                                  checkmarkColor: cs.primary,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color: sel ? cs.primary : cs.onSurface,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: sel
                                          ? cs.primary
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  showCheckmark: true,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      // ── sticky apply bar ─────────────────────
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          MediaQuery.of(ctx).padding.bottom + 16,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border(
                            top: BorderSide(color: cs.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Result count preview
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_previewCount(tempPrice, tempConditions, tempCategories)} items',
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                  Text(
                                    'matching results',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: () {
                                  final appliedQuery =
                                      _searchController.text.trim();
                                  setState(() {
                                    _priceRange = tempPrice;
                                    _selectedSort = tempSort;
                                    _selectedConditions
                                      ..clear()
                                      ..addAll(tempConditions);
                                    _selectedCategories
                                      ..clear()
                                      ..addAll(tempCategories);
                                    _applyAllFilters();
                                  });
                                  Navigator.of(sheetContext).pop();
                                  _openProductListing(
                                    query: appliedQuery,
                                    priceRange: tempPrice,
                                    conditions: tempConditions,
                                    categories: tempCategories,
                                    sort: tempSort,
                                  );
                                },
                                icon: const Icon(Icons.check_rounded),
                                label: const Text(
                                  'Apply',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
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
              },
            );
          },
        );
      },
    );
  }

  // ── Price pill helper ────────────────────────────────────────────────────
  Widget _pricePill(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // ── Price preset chip ────────────────────────────────────────────────────
  Widget _pricePreset(
    BuildContext context,
    String label,
    RangeValues preset,
    RangeValues current,
    ValueChanged<RangeValues> onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    final sel = current.start == preset.start && current.end == preset.end;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: sel ? cs.primary : cs.onSurfaceVariant,
          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      onPressed: () => onTap(preset),
      backgroundColor: sel ? cs.primaryContainer : cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: sel ? cs.primary : cs.outlineVariant),
      ),
    );
  }

  // ── Preview count (for the Apply bar label) ──────────────────────────────
  int _previewCount(
    RangeValues price,
    Set<String> conditions,
    Set<String> categories,
  ) {
    return _buildListingResults(
      query: _searchController.text,
      priceRange: price,
      conditions: conditions,
      categories: categories,
      sort: _selectedSort,
    ).length;
  }

  // ── Apply all filters + sort to _filteredProducts ───────────────────────
  void _applyAllFilters() {
    List<ProductModel> result = _allProducts.where((p) {
      final inPrice =
          p.price >= _priceRange.start && (_priceRange.end >= 2000 ? true : p.price <= _priceRange.end);
      final inCondition =
          _selectedConditions.isEmpty ||
          _selectedConditions.contains(p.condition);
      final inCategory =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(_getCategoryName(p.categoryId));
      return inPrice && inCondition && inCategory;
    }).toList();

    switch (_selectedSort) {
      case 'Price: Low to High':
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Newest First':
        result = result.reversed.toList();
        break;
    }

    _filteredProducts = result;
  }

  void _handleSearchSubmitted(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(_applyAllFilters);
      return;
    }

    _searchFocus.unfocus();
    _openProductListing(query: trimmedQuery);
  }

  Future<void> _openCamera() async {
    await CameraCaptureHelper.pickFromCameraOrGallery(context);
  }

  List<ProductModel> _visibleMarketplaceProducts(List<ProductModel> products) {
    final currentUserId = context.read<UserState>().currentUser?.id;
    return products
        .where((product) => ProductDisplayHelper.isVisibleToUser(product, currentUserId))
        .toList();
  }

  List<ProductModel> _buildListingResults({
    String? query,
    RangeValues? priceRange,
    Set<String>? conditions,
    Set<String>? categories,
    String? sort,
  }) {
    final activePriceRange = priceRange ?? _priceRange;
    final activeConditions = conditions ?? _selectedConditions;
    final activeCategories = categories ?? _selectedCategories;
    final activeSort = sort ?? _selectedSort;
    final lowerQuery = query?.trim().toLowerCase() ?? '';

    final result = _allProducts.where((p) {
      final inPrice =
          p.price >= activePriceRange.start &&
          (activePriceRange.end >= 2000 ? true : p.price <= activePriceRange.end);
      final inCondition =
          activeConditions.isEmpty || activeConditions.contains(p.condition);
      final inCategory =
          activeCategories.isEmpty ||
          activeCategories.contains(_getCategoryName(p.categoryId));
      final matchesQuery =
          lowerQuery.isEmpty ||
          p.title.toLowerCase().contains(lowerQuery) ||
          _getCategoryName(p.categoryId).toLowerCase().contains(lowerQuery) ||
          p.condition.toLowerCase().contains(lowerQuery);

      return inPrice && inCondition && inCategory && matchesQuery;
    }).toList();

    switch (activeSort) {
      case 'Price: Low to High':
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Newest First':
        result.sort(
          (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        );
        break;
    }

    return result;
  }

  void _openProductListing({
    String? query,
    RangeValues? priceRange,
    Set<String>? conditions,
    Set<String>? categories,
    String? sort,
  }) {
    final activeCategories = (categories ?? _selectedCategories).toList()..sort();
    final activeConditions = (conditions ?? _selectedConditions).toList()..sort();
    final trimmedQuery = query?.trim();

    context.push(
      '/product-listing',
      extra: ProductListingArguments(
        allProducts: List<ProductModel>.from(_allProducts),
        initialQuery: trimmedQuery,
        initialSort: sort ?? _selectedSort,
        initialCategories: activeCategories,
        initialConditions: activeConditions,
        initialPriceRange: priceRange ?? _priceRange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildStickyHeader(context),
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _productLoadError != null
                  ? _buildLoadErrorState(context)
                  : _filteredProducts.isEmpty
                  ? _buildEmptyState(context)
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadProducts();
                        await _loadChatConversations();
                      },
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildCategories(context)),
                          _buildSectionHeader(
                            context,
                            title: 'Popular Products',
                            count: _filteredProducts.length,
                          ),
                          _buildPopularProducts(context),
                          _buildSectionHeader(
                            context,
                            title: 'Fresh Arrivals',
                          ),
                          _buildHorizontalProductSection(
                            context,
                            _recentProducts,
                          ),
                          _buildSectionHeader(
                            context,
                            title: 'Budget Finds',
                          ),
                          _buildHorizontalProductSection(
                            context,
                            _budgetProducts,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cartQuantity = context.watch<CartState>().totalQuantity;
    final unreadChats = context.watch<ChatConversationState>().unreadCount;
    final showFilter = _searchController.text.isNotEmpty || _searchFocused;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // ── Search Bar ──────────────────────────────────────
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onSubmitted: _handleSearchSubmitted,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search textbooks, gear...',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: cs.onSurfaceVariant,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(_applyAllFilters);
                            },
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.camera_alt_outlined,
                              color: cs.primary,
                            ),
                            onPressed: _openCamera,
                          ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Cart Button ─────────────────────────────────────
                _buildHeaderIcon(
                  context,
                  icon: Icons.shopping_cart_outlined,
                  onTap: () => context.push('/cart'),
                  badgeCount: cartQuantity,
                ),
              const SizedBox(width: 12),
              // ── Chat Button ─────────────────────────────────────
              _buildHeaderIcon(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => context.push('/messages'),
                badgeCount: unreadChats,
              ),
            ],
          ),
          // ── Filter Row (Conditional) ────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            child: showFilter
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: _hasActiveFilters
                                ? cs.onPrimary
                                : cs.primary,
                          ),
                          label: Text(
                            _hasActiveFilters ? 'Filters Active' : 'Filter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _hasActiveFilters
                                  ? cs.onPrimary
                                  : cs.primary,
                            ),
                          ),
                          onPressed: _showFilterModal,
                          backgroundColor: _hasActiveFilters
                              ? cs.primary
                              : cs.primaryContainer.withValues(alpha: 0.5),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _resetFilters,
                            child: Text(
                              'Clear all',
                              style: TextStyle(color: cs.error, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Icon(icon, color: cs.onSurfaceVariant, size: 24),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                _resetFilters();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear Filters'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load products',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _productLoadError ?? 'Please try again in a moment.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    final categories = [
      {'icon': Icons.menu_book_rounded, 'label': 'Textbooks'},
      {'icon': Icons.laptop_mac_rounded, 'label': 'Electronics'},
      {'icon': Icons.chair_rounded, 'label': 'Dorm Gear'},
      {'icon': Icons.sports_basketball_rounded, 'label': 'Sports'},
      {'icon': Icons.checkroom_rounded, 'label': 'Clothing'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Categories',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return GestureDetector(
                  onTap: () {
                    final label = cat['label'] as String;
                    _searchController.text = label;
                    _handleSearchSubmitted(label);
                  },
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          size: 32,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['label'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularProducts(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = _filteredProducts[index];
          return GestureDetector(
            onTap: () {
              context.push('/product/${product.id}');
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24.0),
                      ),
                      child: Hero(
                        tag: 'product_image_${product.id}',
                        child: ImageHelper.productImage(
                          product.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              CurrencyHelper.formatRM(product.price),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                product.condition,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: _filteredProducts.length),
      ),
    );
  }

  List<ProductModel> get _recentProducts {
    final result = [..._filteredProducts];
    result.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    return result.take(8).toList();
  }

  List<ProductModel> get _budgetProducts {
    final result = [..._filteredProducts];
    result.sort((a, b) => a.price.compareTo(b.price));
    return result.take(8).toList();
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    int? count,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalProductSection(
    BuildContext context,
    List<ProductModel> products,
  ) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 250,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final product = products[index];
            return GestureDetector(
              onTap: () => context.push('/product/${product.id}'),
              child: SizedBox(
                width: 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                          child: ImageHelper.productImage(
                            product.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              CurrencyHelper.formatRM(product.price),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
