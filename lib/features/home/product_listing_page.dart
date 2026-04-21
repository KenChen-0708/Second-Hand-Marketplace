import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/mock_data.dart';
import '../../shared/utils/camera_capture_helper.dart';
import '../../shared/utils/image_helper.dart';
import '../../shared/utils/product_display_helper.dart';
import '../../state/state.dart';

class ProductListingArguments {
  const ProductListingArguments({
    required this.allProducts,
    this.initialQuery,
    this.initialSort = 'Relevance',
    this.initialCategories = const [],
    this.initialConditions = const [],
    this.initialPriceRange = const RangeValues(0, 2000),
  });

  final List<ProductModel> allProducts;
  final String? initialQuery;
  final String initialSort;
  final List<String> initialCategories;
  final List<String> initialConditions;
  final RangeValues initialPriceRange;
}

class ProductListingPage extends StatefulWidget {
  const ProductListingPage({super.key, required this.args});

  final ProductListingArguments args;

  @override
  State<ProductListingPage> createState() => _ProductListingPageState();
}

class _ProductListingPageState extends State<ProductListingPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  late RangeValues _priceRange;
  late String _selectedSort;
  late Set<String> _selectedCategories;
  late Set<String> _selectedConditions;
  late List<ProductModel> _visibleProducts;

  final List<String> _conditions = const [
    'New',
    'Like New',
    'Excellent',
    'Good',
    'Acceptable',
  ];

  final List<String> _sortOptions = const [
    'Relevance',
    'Price: Low to High',
    'Price: High to Low',
    'Newest First',
  ];

  final List<Map<String, dynamic>> _categoryOptions = const [
    {'icon': Icons.menu_book_rounded, 'label': 'Textbooks'},
    {'icon': Icons.laptop_mac_rounded, 'label': 'Electronics'},
    {'icon': Icons.chair_rounded, 'label': 'Dorm Gear'},
    {'icon': Icons.sports_basketball_rounded, 'label': 'Sports'},
    {'icon': Icons.checkroom_rounded, 'label': 'Clothing'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.args.initialQuery?.trim() ?? '';
    _priceRange = widget.args.initialPriceRange;
    _selectedSort = widget.args.initialSort;
    _selectedCategories = widget.args.initialCategories.toSet();
    _selectedConditions = widget.args.initialConditions.toSet();
    _visibleProducts = _buildResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) {
      return 'Uncategorized';
    }

    final category = mockCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => mockCategories[0],
    );
    return category.name;
  }

  bool get _hasActiveFilters =>
      _selectedConditions.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _selectedSort != 'Relevance' ||
      _priceRange != const RangeValues(0, 2000);

  List<ProductModel> _buildResults({
    String? query,
    RangeValues? priceRange,
    Set<String>? conditions,
    Set<String>? categories,
    String? sort,
  }) {
    final activeQuery = (query ?? _searchController.text).trim().toLowerCase();
    final activePriceRange = priceRange ?? _priceRange;
    final activeConditions = conditions ?? _selectedConditions;
    final activeCategories = categories ?? _selectedCategories;
    final activeSort = sort ?? _selectedSort;

    final currentUserId = context.read<UserState>().currentUser?.id;
    final result = widget.args.allProducts.where((product) {
      if (!ProductDisplayHelper.isVisibleToUser(product, currentUserId)) {
        return false;
      }

      final inPrice =
          product.price >= activePriceRange.start &&
          (activePriceRange.end >= 2000
              ? true
              : product.price <= activePriceRange.end);
      final inCondition =
          activeConditions.isEmpty ||
          activeConditions.contains(product.condition);
      final inCategory =
          activeCategories.isEmpty ||
          activeCategories.contains(_getCategoryName(product.categoryId));
      final matchesQuery =
          activeQuery.isEmpty ||
          product.title.toLowerCase().contains(activeQuery) ||
          _getCategoryName(product.categoryId)
              .toLowerCase()
              .contains(activeQuery) ||
          product.condition.toLowerCase().contains(activeQuery);

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

  void _applyListingResults() {
    setState(() {
      _visibleProducts = _buildResults();
    });
  }

  Future<void> _openCamera() async {
    await CameraCaptureHelper.pickFromCameraOrGallery(context);
  }

  void _showFilterModal() {
    RangeValues tempPrice = _priceRange;
    Set<String> tempConditions = Set.from(_selectedConditions);
    Set<String> tempCategories = Set.from(_selectedCategories);
    String tempSort = _selectedSort;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cs = Theme.of(context).colorScheme;
            final tt = Theme.of(context).textTheme;

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

            Widget divider() => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: cs.outlineVariant, height: 1),
            );

            return DraggableScrollableSheet(
              initialChildSize: 0.78,
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
                                      '${(tempConditions.isNotEmpty ? 1 : 0) + (tempCategories.isNotEmpty ? 1 : 0) + (tempSort != 'Relevance' ? 1 : 0) + (tempPrice != const RangeValues(0, 2000) ? 1 : 0)} active',
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
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          children: [
                            sectionLabel('Sort By'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sortOptions.map((option) {
                                final isSelected = tempSort == option;
                                return ChoiceChip(
                                  label: Text(option),
                                  selected: isSelected,
                                  onSelected: (_) =>
                                      setModalState(() => tempSort = option),
                                  selectedColor: cs.primary,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected ? Colors.white : cs.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? cs.primary
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  showCheckmark: false,
                                );
                              }).toList(),
                            ),
                            divider(),
                            sectionLabel('Category'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categoryOptions.map((category) {
                                final label = category['label'] as String;
                                final icon = category['icon'] as IconData;
                                final isSelected = tempCategories.contains(label);

                                return FilterChip(
                                  avatar: Icon(
                                    icon,
                                    size: 16,
                                    color: isSelected
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  label: Text(label),
                                  selected: isSelected,
                                  onSelected: (selected) => setModalState(() {
                                    if (selected) {
                                      tempCategories.add(label);
                                    } else {
                                      tempCategories.remove(label);
                                    }
                                  }),
                                  selectedColor: cs.primaryContainer,
                                  checkmarkColor: cs.primary,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color: isSelected ? cs.primary : cs.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? cs.primary
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  showCheckmark: false,
                                );
                              }).toList(),
                            ),
                            divider(),
                            sectionLabel('Price Range'),
                            Row(
                              children: [
                                _pricePill(context, '\$${tempPrice.start.toInt()}'),
                                const Spacer(),
                                Text(
                                  'to',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                _pricePill(context, '\$${tempPrice.end.toInt()}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: cs.primary,
                                inactiveTrackColor: cs.primaryContainer,
                                thumbColor: cs.primary,
                                overlayColor: cs.primary.withValues(alpha: 0.12),
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
                                onChanged: (value) =>
                                    setModalState(() => tempPrice = value),
                              ),
                            ),
                            divider(),
                            sectionLabel('Condition'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _conditions.map((condition) {
                                final isSelected =
                                    tempConditions.contains(condition);
                                return FilterChip(
                                  label: Text(condition),
                                  selected: isSelected,
                                  onSelected: (selected) => setModalState(() {
                                    if (selected) {
                                      tempConditions.add(condition);
                                    } else {
                                      tempConditions.remove(condition);
                                    }
                                  }),
                                  selectedColor: cs.primaryContainer,
                                  checkmarkColor: cs.primary,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color: isSelected ? cs.primary : cs.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? cs.primary
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          MediaQuery.of(context).padding.bottom + 16,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border(
                            top: BorderSide(color: cs.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_buildResults(query: _searchController.text, priceRange: tempPrice, conditions: tempConditions, categories: tempCategories, sort: tempSort).length} items',
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
                                    _selectedConditions = Set.from(tempConditions);
                                    _selectedCategories = Set.from(tempCategories);
                                    _visibleProducts = _buildResults();
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

  Widget _buildTopBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onSubmitted: (_) => _applyListingResults(),
              onChanged: (_) => setState(() {}),
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
                          _applyListingResults();
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
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _hasActiveFilters ? cs.primary : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _showFilterModal,
              icon: Icon(
                Icons.tune_rounded,
                color: _hasActiveFilters ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_visibleProducts.length} product${_visibleProducts.length == 1 ? '' : 's'} found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_searchController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Search: "${_searchController.text.trim()}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_selectedSort != 'Relevance') _InfoChip(label: _selectedSort),
                ...(_selectedCategories.toList()..sort()).map(
                  (item) => _InfoChip(label: item),
                ),
                ...(_selectedConditions.toList()..sort()).map(
                  (item) => _InfoChip(label: item),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _visibleProducts.isEmpty
                  ? Column(
                      children: [
                        _buildSummary(context),
                        const Expanded(child: _EmptyState()),
                      ],
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildSummary(context)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.74,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = _visibleProducts[index];
                              return GestureDetector(
                                onTap: () => context.push('/product/${product.id}'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(24),
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
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '\$${product.price.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: cs.primary,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: cs.primaryContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      product.condition,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: cs.primary,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
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
                            }, childCount: _visibleProducts.length),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your search or filters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
