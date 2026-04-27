import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../state/state.dart';
import '../../services/local/admin_search_preferences_service.dart';
import '../../shared/widgets/admin_search_history_section.dart';

class AdminListingModerationPage extends StatefulWidget {
  const AdminListingModerationPage({super.key});

  @override
  State<AdminListingModerationPage> createState() =>
      _AdminListingModerationPageState();
}

class _AdminListingModerationPageState
    extends State<AdminListingModerationPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _searchHistory = [];
  StreamSubscription<String?>? _clearSearchSubscription;
  String _searchQuery = '';
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChange);
    _clearSearchSubscription = AdminSearchPreferencesService.instance
        .clearCurrentSearchStream
        .listen(_handleClearSearchRequest);
    _restoreSearchHistory();
    _refresh();
  }

  @override
  void dispose() {
    _persistSearchToHistory();
    _clearSearchSubscription?.cancel();
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductState>().fetchProducts(status: null);
    });
  }

  Future<void> _restoreSearchHistory() async {
    final history = await AdminSearchPreferencesService.instance
        .readSearchHistory(AdminSearchPreferenceKeys.listingModeration);
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = history);
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _handleSearchFocusChange() {
    if (!_searchFocusNode.hasFocus) {
      _persistSearchToHistory();
    }
  }

  void _persistSearchToHistory() {
    final value = _searchController.text.trim();
    if (value.isEmpty) {
      return;
    }

    unawaited(_saveSearchHistoryEntry(value));
  }

  Future<void> _saveSearchHistoryEntry(String value) async {
    final history = await AdminSearchPreferencesService.instance
        .addSearchHistoryEntry(
          AdminSearchPreferenceKeys.listingModeration,
          value,
        );
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = history);
  }

  Future<void> _selectSearchHistoryEntry(String value) async {
    _searchController.text = value;
    _handleSearchChanged(value);
    await _saveSearchHistoryEntry(value);
  }

  Future<void> _removeSearchHistoryEntry(String value) async {
    final history = await AdminSearchPreferencesService.instance
        .removeSearchHistoryEntry(
          AdminSearchPreferenceKeys.listingModeration,
          value,
        );
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = history);
  }

  Future<void> _clearSearchHistory() async {
    await AdminSearchPreferencesService.instance.clearSearchHistory(
      AdminSearchPreferenceKeys.listingModeration,
    );
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = []);
  }

  void _handleClearSearchRequest(String? key) {
    if (key != null && key != AdminSearchPreferenceKeys.listingModeration) {
      return;
    }

    _persistSearchToHistory();
    if (!mounted) {
      return;
    }

    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildFilters(),
              const SizedBox(height: 24),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await context.read<ProductState>().fetchProducts(status: null);
                  },
                  child: Consumer<ProductState>(
                    builder: (context, productState, child) {
                      if (productState.isLoading && productState.items.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final filteredListings = productState.items.where((p) {
                        final matchesSearch = p.title
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                        final matchesStatus = _selectedStatus == 'all' ||
                            p.status.toLowerCase() == _selectedStatus;
                        return matchesSearch && matchesStatus;
                      }).toList();

                      if (filteredListings.isEmpty) {
                        return ListView(
                          children: [
                            const SizedBox(height: 100),
                            const Center(
                              child: Text('No listings found matching your criteria.'),
                            ),
                          ],
                        );
                      }

                      return GridView.builder(
                        gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 350,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredListings.length,
                        itemBuilder: (context, index) {
                          final product = filteredListings[index];
                          return _buildListingCard(product);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Listing Moderation',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage platform listings. Tap to view full details or share with staff.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search listings...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _handleSearchChanged,
                onSubmitted: _saveSearchHistoryEntry,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(value: 'sold', child: Text('Sold')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ),
            ),
          ],
        ),
        if (_searchHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          AdminSearchHistorySection(
            history: _searchHistory,
            onSelected: _selectSearchHistoryEntry,
            onDeleted: _removeSearchHistoryEntry,
            onClearAll: _clearSearchHistory,
          ),
        ],
      ],
    );
  }

  Widget _buildListingCard(ProductModel product) {
    final bool isInactive = product.status.toLowerCase() == 'inactive';

    return InkWell(
      onTap: () => context.push('/product/${product.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      product.imageUrl ?? 'https://via.placeholder.com/400',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: Icon(
                            Icons.image_rounded,
                            size: 64,
                            color: Colors.black26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildStatusChip(product.status),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Share.share('Check this listing for moderation: ${product.title} \n ID: ${product.id}'),
                        icon: const Icon(Icons.share_rounded, size: 20, color: Colors.blueAccent),
                        tooltip: 'Share Listing',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_productImages(product).length} photo${_productImages(product).length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _openPhotoEvidenceReview(product),
                        icon: const Icon(Icons.verified_outlined, size: 16),
                        label: const Text('Review'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _toggleStatus(product),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: isInactive ? Colors.green : Colors.orange,
                            side: BorderSide(
                              color: isInactive ? Colors.green : Colors.orange,
                            ),
                          ),
                          child: Text(isInactive ? 'Activate' : 'Deactivate', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _confirmDelete(product),
                        icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                        tooltip: 'Delete Permanently',
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
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'inactive':
        color = Colors.orange;
        break;
      case 'sold':
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<String> _productImages(ProductModel product) {
    final images = <String>[
      ...?product.images?.where((image) => image.trim().isNotEmpty),
    ];
    final heroImage = product.imageUrl;
    if (heroImage != null &&
        heroImage.trim().isNotEmpty &&
        !images.contains(heroImage)) {
      images.insert(0, heroImage);
    }
    return images;
  }

  Future<void> _openPhotoEvidenceReview(ProductModel product) async {
    final images = _productImages(product);
    final noteController = TextEditingController();
    final pageController = PageController();
    var selectedIndex = 0;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Photo Evidence Review',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  product.title,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 720;
                            final preview = _buildPhotoReviewPreview(
                              context,
                              images,
                              selectedIndex,
                              pageController,
                              onPageChanged: (index) {
                                setDialogState(() => selectedIndex = index);
                              },
                              onThumbnailTap: (index) {
                                setDialogState(() => selectedIndex = index);
                                pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                            );
                            final details = _buildPhotoReviewDetails(
                              context,
                              product,
                              images,
                              noteController,
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: preview),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 2, child: details),
                                ],
                              );
                            }

                            return ListView(
                              children: [
                                SizedBox(height: 420, child: preview),
                                const SizedBox(height: 20),
                                details,
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Close'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _submitPhotoReview(
                              product: product,
                              decision: 'approved',
                              nextStatus:
                                  product.status.toLowerCase() == 'sold'
                                      ? 'sold'
                                      : 'active',
                              notes: noteController.text.trim(),
                              reviewedImages: images.length,
                            ).whenComplete(() {
                              if (mounted && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            }),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Approve Photos'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _submitPhotoReview(
                              product: product,
                              decision: 'flagged',
                              nextStatus: 'inactive',
                              notes: noteController.text.trim(),
                              reviewedImages: images.length,
                            ).whenComplete(() {
                              if (mounted && dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            }),
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Flag and Deactivate'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    pageController.dispose();
  }

  Widget _buildPhotoReviewPreview(
    BuildContext context,
    List<String> images,
    int selectedIndex,
    PageController pageController, {
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onThumbnailTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: images.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.no_photography_outlined,
                            size: 56, color: Colors.black26),
                        SizedBox(height: 12),
                        Text('No listing photos uploaded.'),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: images.length,
                      onPageChanged: onPageChanged,
                      itemBuilder: (context, index) {
                        return InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 3,
                          child: Image.network(
                            images[index],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: const Color(0xFFF3F4F6),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 56,
                                color: Colors.black26,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (images.isNotEmpty) ...[
          Text(
            'Image ${selectedIndex + 1} of ${images.length}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onThumbnailTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.black12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.black26,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoReviewDetails(
    BuildContext context,
    ProductModel product,
    List<String> images,
    TextEditingController noteController,
  ) {
    final hasEnoughPhotos = images.length >= 3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moderation Checklist',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildEvidenceRow(
              icon: Icons.photo_library_outlined,
              label: 'Photos uploaded',
              value: '${images.length}',
              highlight: hasEnoughPhotos ? Colors.green : Colors.orange,
            ),
            _buildEvidenceRow(
              icon: Icons.inventory_2_outlined,
              label: 'Listing status',
              value: product.status.toUpperCase(),
            ),
            _buildEvidenceRow(
              icon: Icons.sell_outlined,
              label: 'Condition declared',
              value: product.condition,
            ),
            _buildEvidenceRow(
              icon: Icons.person_outline,
              label: 'Seller ID',
              value: product.sellerId,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasEnoughPhotos
                    ? Colors.green.withOpacity(0.08)
                    : Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                hasEnoughPhotos
                    ? 'Photo set looks sufficient for a manual review.'
                    : 'Photo set is limited. Consider deactivating until clearer evidence is provided.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Internal moderation notes',
                hintText:
                    'Record missing angles, suspicious edits, or other evidence findings.',
                alignLabelWithHint: true,
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceRow({
    required IconData icon,
    required String label,
    required String value,
    Color? highlight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (highlight ?? Colors.blueGrey).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: highlight ?? Colors.blueGrey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPhotoReview({
    required ProductModel product,
    required String decision,
    required String nextStatus,
    required String notes,
    required int reviewedImages,
  }) async {
    try {
      await context.read<ProductState>().updateProduct(product.id, {
        'status': nextStatus,
        'title': product.title,
      });
      // Log the review action — non-fatal: a failure here should not block
      // the status update that already succeeded.
      try {
        await _logPhotoReview(
          product: product,
          decision: decision,
          previousStatus: product.status,
          nextStatus: nextStatus,
          notes: notes,
          reviewedImages: reviewedImages,
        );
      } catch (_) {
        // Logging failure is non-critical; swallow silently.
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'approved'
                  ? 'Photo review approved. Listing status is $nextStatus.'
                  : 'Photo review flagged. Listing moved to $nextStatus.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      rethrow;
    }
  }

  Future<void> _logPhotoReview({
    required ProductModel product,
    required String decision,
    required String previousStatus,
    required String nextStatus,
    required String notes,
    required int reviewedImages,
  }) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) {
      return;
    }

    await _supabase.from('admin_logs').insert({
      'admin_id': adminId,
      'action': 'listing_photo_review',
      'entity_type': 'product',
      'entity_id': product.id,
      'details': {
        'decision': decision,
        'product_title': product.title,
        'previous_status': previousStatus,
        'next_status': nextStatus,
        'reviewed_images': reviewedImages,
        'notes': notes,
      },
    });
  }

  Future<void> _toggleStatus(ProductModel product) async {
    final newStatus = product.status.toLowerCase() == 'active' ? 'inactive' : 'active';
    try {
      await context.read<ProductState>().updateProduct(product.id, {
        'status': newStatus,
        'title': product.title,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Listing marked as $newStatus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text(
          'Are you sure you want to delete "${product.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<ProductState>().deleteProduct(product.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Listing deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
