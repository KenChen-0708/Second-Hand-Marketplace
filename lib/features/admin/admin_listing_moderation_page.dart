import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../models/mock_data.dart';

class AdminListingModerationPage extends StatefulWidget {
  const AdminListingModerationPage({super.key});

  @override
  State<AdminListingModerationPage> createState() =>
      _AdminListingModerationPageState();
}

class _AdminListingModerationPageState
    extends State<AdminListingModerationPage> {
  late List<ProductModel> _listings;
  final Set<String> _flaggedIds = {};

  @override
  void initState() {
    super.initState();
    _listings = List.from(mockProducts);
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
              Text(
                'Listing Moderation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Manage all active listings on the platform. Flag or remove inappropriate items.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    final product = _listings[index];
                    return _buildListingCard(product, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingCard(ProductModel product, int index) {
    bool isReported = _flaggedIds.contains(product.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isReported
            ? Border.all(color: Colors.orange, width: 2)
            : Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
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
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReported)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Flagged for Review',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
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
                  'Seller: ${_getSeller(product).name}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _confirmFlag(product, index),
                      icon: const Icon(
                        Icons.flag_rounded,
                        size: 18,
                        color: Colors.orange,
                      ),
                      label: const Text(
                        'Flag',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(product, index),
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                      tooltip: 'Delete Listing',
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

  UserModel _getSeller(ProductModel product) {
    final sellers = [mockUserBuyer, mockUserSeller1, mockUserSeller2];
    return sellers.firstWhere(
      (u) => u.id == product.sellerId,
      orElse: () => mockUserSeller1,
    );
  }

  void _confirmDelete(ProductModel product, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text(
          'Are you sure you want to permanently delete "${product.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _listings.removeAt(index));
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Listing deleted.')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmFlag(ProductModel product, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flag Listing'),
        content: Text(
          'Mark "${product.title}" as requiring manual review? It will be hidden from search results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              setState(() => _flaggedIds.add(product.id));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing flagged for review.')),
              );
            },
            child: const Text('Flag Item'),
          ),
        ],
      ),
    );
  }
}
