import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../../shared/utils/product_display_helper.dart';
import '../../state/state.dart';

class SellerProductPage extends StatelessWidget {
  const SellerProductPage({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final images = product.images ?? (product.imageUrl != null ? [product.imageUrl!] : <String>[]);
    final displayImages = images.isEmpty ? <String?>[null] : images.cast<String?>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Seller Product', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 320,
            child: PageView(
              children: displayImages
                  .map(
                    (image) => ImageHelper.productImage(
                      image,
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.cover,
                    ),
                  )
                  .toList(),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ),
                    _pill(product.status.toUpperCase(), _statusColor(product.status)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(product.condition.replaceAll('_', ' ').toUpperCase(), Colors.blueGrey),
                    _pill('${product.stockQuantity ?? 0} AVAILABLE', Colors.indigo),
                    if (product.openToOffers) _pill('OPEN TO OFFERS', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          _section(
            title: 'Description',
            child: Text(
              product.description,
              style: const TextStyle(height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
          _section(
            title: 'Trade Method',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.tradePreference
                  .map((pref) => _pill(ProductDisplayHelper.formatTradePreference(pref), Colors.teal))
                  .toList(),
            ),
          ),
          _section(
            title: 'Performance',
            child: Row(
              children: [
                Expanded(child: _metric('Views', product.viewCount.toString(), Icons.visibility_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _metric('Likes', product.likesCount.toString(), Icons.favorite_border_rounded)),
              ],
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/edit-product', extra: product),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit Listing'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmRemove(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Listing?'),
        content: const Text('This listing will be removed from the marketplace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await context.read<ProductState>().deleteProduct(product.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing removed successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove listing: $e')),
        );
      }
    }
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981);
      case 'sold':
        return Colors.grey;
      case 'inactive':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }
}
