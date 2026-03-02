import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- Search State ---
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = mockProducts;

  // --- Filter State ---
  RangeValues _priceRange = const RangeValues(0, 600);
  final Set<String> _selectedConditions = {};

  final List<String> _conditions = [
    'New',
    'Like New',
    'Excellent',
    'Good',
    'Acceptable',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Search Logic ---
  void _onSearchSubmitted(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredProducts = mockProducts;
      } else {
        final lowerQuery = query.trim().toLowerCase();
        _filteredProducts = mockProducts.where((p) {
          return p.title.toLowerCase().contains(lowerQuery) ||
              p.category.toLowerCase().contains(lowerQuery) ||
              p.condition.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
    print('[Search] Query: "$query" → ${_filteredProducts.length} result(s)');
  }

  // --- Filter Reset Logic ---

  void _resetFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 600);
      _selectedConditions.clear();
      _filteredProducts = mockProducts;
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
      _priceRange != const RangeValues(0, 600);

  // --- Filter Modal ---
  void _showFilterModal() {
    // Temp copies — committed only on Apply
    RangeValues tempPrice = _priceRange;
    Set<String> tempConditions = Set.from(_selectedConditions);
    Set<String> tempCategories = Set.from(_selectedCategories);
    String tempSort = _selectedSort;

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
                                    tempPrice != const RangeValues(0, 600))
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
                                    tempPrice = const RangeValues(0, 600);
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
                                _pricePill(ctx, '\$${tempPrice.start.toInt()}'),
                                const Spacer(),
                                Text(
                                  'to',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                _pricePill(ctx, '\$${tempPrice.end.toInt()}'),
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
                                max: 600,
                                divisions: 60,
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
                                  'Under \$50',
                                  const RangeValues(0, 50),
                                  tempPrice,
                                  (v) => setModalState(() => tempPrice = v),
                                ),
                                _pricePreset(
                                  ctx,
                                  '\$50–\$150',
                                  const RangeValues(50, 150),
                                  tempPrice,
                                  (v) => setModalState(() => tempPrice = v),
                                ),
                                _pricePreset(
                                  ctx,
                                  '\$150–\$400',
                                  const RangeValues(150, 400),
                                  tempPrice,
                                  (v) => setModalState(() => tempPrice = v),
                                ),
                                _pricePreset(
                                  ctx,
                                  'Over \$400',
                                  const RangeValues(400, 600),
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
    return mockProducts.where((p) {
      final inPrice = p.price >= price.start && p.price <= price.end;
      final inCondition =
          conditions.isEmpty || conditions.contains(p.condition);
      final inCategory = categories.isEmpty || categories.contains(p.category);
      return inPrice && inCondition && inCategory;
    }).length;
  }

  // ── Apply all filters + sort to _filteredProducts ───────────────────────
  void _applyAllFilters() {
    List<Product> result = mockProducts.where((p) {
      final inPrice =
          p.price >= _priceRange.start && p.price <= _priceRange.end;
      final inCondition =
          _selectedConditions.isEmpty ||
          _selectedConditions.contains(p.condition);
      final inCategory =
          _selectedCategories.isEmpty ||
          _selectedCategories.contains(p.category);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildStickyHeader(context),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? _buildEmptyState(context)
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildCategories(context)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Text(
                                  'Popular Products',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_filteredProducts.length}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildPopularProducts(context),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: _onSearchSubmitted,
              onChanged: (value) {
                if (value.isEmpty) {
                  setState(() => _filteredProducts = mockProducts);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search textbooks, gear...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                // Search icon on the left — tapping it submits the search
                prefixIcon: GestureDetector(
                  onTap: () => _onSearchSubmitted(_searchController.text),
                  child: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                // Camera icon on the right — inside the pill
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    // Camera / QR scanner action
                  },
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filter Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hasActiveFilters
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
            ),
            child: IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: _hasActiveFilters
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: _showFilterModal,
            ),
          ),
          const SizedBox(width: 12),

          // Cart Button
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => context.push('/cart'),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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
                    _onSearchSubmitted(label);
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
              context.push('/home/product/${product.id}');
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
                        child: Image.network(
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
                              '\$${product.price.toStringAsFixed(2)}',
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
}
