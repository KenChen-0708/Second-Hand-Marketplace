import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/product/product_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/order/order_service.dart';
import '../../shared/utils/image_helper.dart';
import '../../state/state.dart';

class ListingDetailArguments {
  const ListingDetailArguments({
    required this.product,
    required this.orders,
  });

  final ProductModel product;
  final List<OrderModel> orders;
}

class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key});

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  final ProductService _productService = ProductService();
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();

  List<ProductModel> _activeProducts = [];
  List<ProductModel> _soldProducts = [];
  Map<String, List<OrderModel>> _ordersByProductId = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMyProducts();
  }

  Future<void> _fetchMyProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _authService.supabase.auth.currentUser?.email;
      if (email == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'User not logged in';
          });
        }
        return;
      }

      final currentUser = await _authService.fetchProfileByEmail(email);
      final sellerId = currentUser.id;

      final active = await _productService.fetchProducts(
        status: 'active',
        sellerId: sellerId,
      );
      final sold = await _productService.fetchProducts(
        status: 'sold',
        sellerId: sellerId,
      );
      final sellerOrders = await _orderService.getSellerOrders(sellerId);
      final ordersByProductId = <String, List<OrderModel>>{};
      for (final order in sellerOrders) {
        for (final item in order.orderItems) {
          if (item.product?.sellerId != sellerId) {
            continue;
          }
          final productOrders =
              ordersByProductId.putIfAbsent(item.productId, () => []);
          if (!productOrders.any((existing) => existing.id == order.id)) {
            productOrders.add(order);
          }
        }
      }

      active.sort((a, b) {
        final aNeedsAction = _needsActionCountFor(a.id, ordersByProductId);
        final bNeedsAction = _needsActionCountFor(b.id, ordersByProductId);
        if (aNeedsAction != bNeedsAction) {
          return bNeedsAction.compareTo(aNeedsAction);
        }
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _activeProducts = active;
          _soldProducts = sold;
          _ordersByProductId = ordersByProductId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            'My Listings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Active (${_activeProducts.length})'),
              Tab(text: 'Sold (${_soldProducts.length})'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchMyProducts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    children: [
                      RefreshIndicator(
                        onRefresh: _fetchMyProducts,
                        child: _buildListingTab(context, _activeProducts),
                      ),
                      RefreshIndicator(
                        onRefresh: _fetchMyProducts,
                        child: _buildListingTab(context, _soldProducts, isSold: true),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildListingTab(
    BuildContext context,
    List<ProductModel> products, {
    bool isSold = false,
  }) {
    if (products.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No listings found.')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final product = products[index];
        final relatedOrders = _ordersByProductId[product.id] ?? const [];
        final needsActionCount = _needsActionCountFor(product.id, _ordersByProductId);
        return InkWell(
          onTap: () async {
            await context.push(
              '/profile/listings/detail',
              extra: ListingDetailArguments(
                product: product,
                orders: relatedOrders,
              ),
            );
            if (mounted) {
              await _fetchMyProducts();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Hero(
                      tag: 'product_image_${product.id}',
                      child: ImageHelper.productImage(
                        product.imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
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
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSold
                                    ? Colors.grey[300]
                                    : Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSold ? 'SOLD' : 'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSold
                                      ? Colors.grey[700]
                                      : Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (needsActionCount > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$needsActionCount buyer ${needsActionCount == 1 ? 'action' : 'actions'} needed',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _needsActionCountFor(
    String productId,
    Map<String, List<OrderModel>> ordersByProductId,
  ) {
    final orders = ordersByProductId[productId] ?? const [];
    return orders
        .where((order) => const {'pending', 'paid', 'pending_handover'}
            .contains(order.status.toLowerCase()))
        .length;
  }
}

class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, required this.args});

  final ListingDetailArguments args;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  final OrderService _orderService = OrderService();
  late List<OrderModel> _orders;
  bool _isReloading = false;

  @override
  void initState() {
    super.initState();
    _orders = [...widget.args.orders];
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.args.product;
    final orders = [..._orders]
      ..sort((a, b) {
        final aAction = _needsAction(a.status) ? 1 : 0;
        final bAction = _needsAction(b.status) ? 1 : 0;
        if (aAction != bAction) return bAction.compareTo(aAction);
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    final actionCount = orders.where((order) => _needsAction(order.status)).length;
    final statusColor = actionCount > 0 ? Colors.orange : Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Listing Details', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reloadOrders,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          actionCount > 0 ? Icons.notification_important_rounded : Icons.storefront_rounded,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              actionCount > 0 ? '$actionCount buyer action needed' : 'Listing is active',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              actionCount > 0
                                  ? 'Review buyer orders for this listing.'
                                  : 'No buyer action is waiting right now.',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _section(
                  title: 'Listing Summary',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ImageHelper.productImage(
                          product.imageUrl,
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _pill(product.status.toUpperCase(), Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _section(
                  title: 'Information',
                  child: Column(
                    children: [
                      _infoRow('Condition', product.condition.replaceAll('_', ' ').toUpperCase()),
                      _infoRow('Stock', '${product.stockQuantity ?? 0} available'),
                      _infoRow('Views', product.viewCount.toString()),
                      _infoRow('Likes', product.likesCount.toString()),
                      if (product.description.trim().isNotEmpty)
                        _infoRow('Description', product.description),
                    ],
                  ),
                ),
                _section(
                  title: 'Buyer Orders',
                  child: orders.isEmpty
                      ? Text(
                          'No buyer has purchased this listing yet.',
                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                        )
                      : Column(
                          children: orders.map((order) => _orderCard(context, order)).toList(),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/edit-product', extra: product),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Edit Listing'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/product/${product.id}'),
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('View Public'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isReloading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.06),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reloadOrders() async {
    setState(() => _isReloading = true);
    try {
      final sellerOrders = await _orderService.getSellerOrders(widget.args.product.sellerId);
      final updatedOrders = <OrderModel>[];
      for (final order in sellerOrders) {
        final hasProduct = order.orderItems.any(
          (item) => item.productId == widget.args.product.id,
        );
        if (hasProduct && !updatedOrders.any((item) => item.id == order.id)) {
          updatedOrders.add(order);
        }
      }

      if (!mounted) {
        return;
      }
      setState(() => _orders = updatedOrders);
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
      }
    }
  }

  static bool _needsAction(String status) {
    return const {'pending', 'paid', 'pending_handover'}.contains(status.toLowerCase());
  }

  Widget _orderCard(BuildContext context, OrderModel order) {
    final date = order.createdAt == null ? '' : DateFormat('MMM dd, yyyy').format(order.createdAt!);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _needsAction(order.status)
              ? Colors.orange.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _needsAction(order.status) ? Icons.notification_important_rounded : Icons.receipt_long_rounded,
                color: _needsAction(order.status) ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.buyer?.name ?? 'Buyer',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${order.orderNumber} ${date.isEmpty ? '' : '- $date'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              _pill(order.status.replaceAll('_', ' ').toUpperCase(), _statusColor(order.status)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await context.push('/profile/order-status', extra: order);
                    if (context.mounted) {
                      await _reloadOrders();
                    }
                  },
                  child: const Text('Open Order'),
                ),
              ),
              if (order.status.toLowerCase() == 'pending') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus(context, order, 'paid'),
                    child: const Text('Confirm'),
                  ),
                ),
              ] else if (order.status.toLowerCase() == 'paid') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus(context, order, 'pending_handover'),
                    child: const Text('Ready'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(
    BuildContext context,
    OrderModel order,
    String status,
  ) async {
    try {
      await context.read<OrderState>().updateOrderStatus(order.id, status);
      if (context.mounted) {
        await _reloadOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order updated to ${status.replaceAll('_', ' ')}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: $e')),
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
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'paid':
        return Colors.orange;
      case 'pending_handover':
        return Colors.indigo;
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return Colors.grey;
      case 'disputed':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }
}
