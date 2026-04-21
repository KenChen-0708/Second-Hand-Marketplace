import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../../state/state.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';

  final List<String> _statusFilters = [
    'All',
    'Ongoing',
    'Awaiting Action',
    'Completed',
    'Cancelled',
    'Disputed',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    final userState = context.read<UserState>();
    final orderState = context.read<OrderState>();
    if (userState.currentUser != null) {
      await orderState.fetchBuyerOrders(userState.currentUser!.id);
    }
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    final userState = context.read<UserState>();
    final currentUserId = userState.currentUser?.id ?? '';

    return orders.where((order) {
      // Role Filter - Only show buying orders
      if (!order.isBuyer(currentUserId)) return false;

      // Status Filter
      bool matchesStatus = true;
      final status = order.status.toLowerCase();
      if (_selectedStatus == 'Ongoing') {
        matchesStatus = ['pending', 'paid', 'pending_handover'].contains(status);
      } else if (_selectedStatus == 'Awaiting Action') {
        matchesStatus = status == 'pending_handover'; // Buyer needs to confirm receipt
      } else if (_selectedStatus != 'All') {
        matchesStatus = status == _selectedStatus.toLowerCase();
      }

      if (!matchesStatus) return false;

      // Search Filter
      final query = _searchController.text.toLowerCase();
      final matchesSearch = query.isEmpty ||
          order.orderNumber.toLowerCase().contains(query) ||
          (order.primarySellerName?.toLowerCase().contains(query) ?? false) ||
          (order.handoverLocation?.toLowerCase().contains(query) ?? false) ||
          order.orderItems.any(
            (item) => item.product?.title.toLowerCase().contains(query) ?? false,
          );

      return matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final filteredOrders = _getFilteredOrders(orderState.items);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Purchase History',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: orderState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredOrders.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: _refreshOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(context, filteredOrders[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search title, seller, location...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedStatus == filter;
                return ChoiceChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedStatus = selected ? filter : 'All');
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Colors.grey[200],
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide.none,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          const Text(
            'No purchases yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final firstProduct = order.orderItems.isNotEmpty
        ? order.orderItems.first.product
        : null;
    
    final otherPartyName = order.primarySellerName ?? 'Unknown Seller';
    final statusInfo = _getStatusDisplayInfo(order.status);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await context.push('/profile/order-status', extra: order);
              if (context.mounted) {
                await _refreshOrders();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'BUYING',
                          style: TextStyle(
                            color: Colors.indigo[700],
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bought from ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Flexible(
                        child: Text(
                          otherPartyName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '#${order.orderNumber}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'order_img_${order.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ImageHelper.productImage(
                            firstProduct?.imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstProduct?.title ?? 'Product Title',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (order.orderItems.length > 1)
                              Text(
                                '+ ${order.orderItems.length - 1} more items',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            const SizedBox(height: 8),
                            _buildStatusBadge(statusInfo),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${order.totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.createdAt != null ? dateFormat.format(order.createdAt!) : '',
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (order.handoverLocation != null || order.handoverDate != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${order.handoverLocation ?? 'No location'} · ${order.handoverDate != null ? DateFormat('MMM dd, HH:mm').format(order.handoverDate!) : 'TBD'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoPhotoPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 24),
    );
  }

  Widget _buildStatusBadge(_StatusInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: info.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 12, color: info.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              info.label,
              style: TextStyle(
                color: info.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusDisplayInfo(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _StatusInfo(
          label: 'Awaiting Confirmation',
          explanation: 'Seller has not prepared the item yet',
          color: Colors.orange,
          icon: Icons.hourglass_empty_rounded,
        );
      case 'paid':
        return _StatusInfo(
          label: 'Paid · Ready to Ship',
          explanation: 'Payment confirmed, awaiting handover',
          color: Colors.blue,
          icon: Icons.payments_outlined,
        );
      case 'pending_handover':
        return _StatusInfo(
          label: 'Ready for Handover',
          explanation: 'Meet-up scheduled',
          color: Colors.indigo,
          icon: Icons.handshake_outlined,
        );
      case 'completed':
        return _StatusInfo(
          label: 'Completed',
          explanation: 'Transaction finished successfully',
          color: const Color(0xFF10B981),
          icon: Icons.check_circle_outline_rounded,
        );
      case 'cancelled':
        return _StatusInfo(
          label: 'Cancelled',
          explanation: 'This order was cancelled',
          color: Colors.grey,
          icon: Icons.cancel_outlined,
        );
      case 'disputed':
        return _StatusInfo(
          label: 'Disputed',
          explanation: 'Being reviewed by support',
          color: Colors.redAccent,
          icon: Icons.gavel_rounded,
        );
      default:
        return _StatusInfo(
          label: status,
          explanation: '',
          color: Colors.grey,
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final String explanation;
  final Color color;
  final IconData icon;

  _StatusInfo({
    required this.label,
    required this.explanation,
    required this.color,
    required this.icon,
  });
}
