import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../services/local/admin_search_preferences_service.dart';
import '../../shared/widgets/admin_search_history_section.dart';
import '../../state/state.dart';
import 'widgets/admin_cached_product_image.dart';

class AdminListingModerationPage extends StatefulWidget {
  const AdminListingModerationPage({super.key});

  @override
  State<AdminListingModerationPage> createState() =>
      _AdminListingModerationPageState();
}

class _AdminListingModerationPageState
    extends State<AdminListingModerationPage> {
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
    _clearSearchSubscription = AdminSearchPreferencesService
        .instance
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
          padding: const EdgeInsets.all(24),
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
                    await context.read<ProductState>().fetchProducts(
                      status: null,
                    );
                  },
                  child: Consumer<ProductState>(
                    builder: (context, productState, child) {
                      if (productState.isLoading &&
                          productState.items.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final filteredListings = productState.items.where((p) {
                        final matchesSearch = p.title.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                        final matchesStatus =
                            _selectedStatus == 'all' ||
                            p.status.toLowerCase() == _selectedStatus;
                        return matchesSearch && matchesStatus;
                      }).toList();

                      if (filteredListings.isEmpty) {
                        return ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'No listings found matching your criteria.',
                              ),
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
          'Manage platform listings and share them with staff for moderation.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
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
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                    }
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
    final isInactive = product.status.toLowerCase() == 'inactive';

    return Container(
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
                  child: AdminCachedProductImage(
                    imageUrl: product.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
                      onPressed: () => Share.share(
                        _buildListingShareMessage(product),
                      ),
                      icon: const Icon(
                        Icons.share_rounded,
                        size: 20,
                        color: Colors.blueAccent,
                      ),
                      tooltip: 'Share Listing',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
                    const Icon(
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
                          foregroundColor: isInactive
                              ? Colors.green
                              : Colors.orange,
                          side: BorderSide(
                            color: isInactive ? Colors.green : Colors.orange,
                          ),
                        ),
                        child: Text(
                          isInactive ? 'Activate' : 'Deactivate',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _confirmDelete(product),
                      icon: const Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'Delete Permanently',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    var color = Colors.grey;
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

  String _buildListingShareMessage(ProductModel product) {
    final photoCount = _productImages(product).length;
    final sellerName = product.sellerName?.trim();

    return [
      'Listing moderation review',
      'Title: ${product.title}',
      'Listing ID: ${product.id}',
      'Status: ${product.status.toUpperCase()}',
      'Price: RM ${product.price.toStringAsFixed(2)}',
      if (sellerName != null && sellerName.isNotEmpty) 'Seller: $sellerName',
      'Photos: $photoCount',
      'Please review this listing for moderation.',
    ].join('\n');
  }

  Future<void> _toggleStatus(ProductModel product) async {
    final newStatus = product.status.toLowerCase() == 'active'
        ? 'inactive'
        : 'active';
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
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
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
