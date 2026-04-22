import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../state/state.dart';
import '../../models/models.dart';
import '../../services/chat/chat_service.dart';
import '../../shared/utils/image_helper.dart';

class AdminOrderManagementPage extends StatefulWidget {
  const AdminOrderManagementPage({super.key});

  @override
  State<AdminOrderManagementPage> createState() =>
      _AdminOrderManagementPageState();
}

class _AdminOrderManagementPageState extends State<AdminOrderManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  DateTimeRange? _dateRange;
  RangeValues _priceRange = const RangeValues(0, 10000);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderState>().fetchAllOrders();
      context.read<DisputeState>().fetchAllDisputes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<OrderModel> _applyFilters(List<OrderModel> orders) {
    return orders.where((order) {
      final matchesSearch = order.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (order.buyer?.name ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (order.primarySellerName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _statusFilter == 'all' || order.status.toLowerCase() == _statusFilter.toLowerCase();
      
      final orderDate = order.createdAt ?? DateTime.now();
      final matchesDate = _dateRange == null || 
          (orderDate.isAfter(_dateRange!.start) && orderDate.isBefore(_dateRange!.end.add(const Duration(days: 1))));
      
      final matchesPrice = order.totalPrice >= _priceRange.start && order.totalPrice <= _priceRange.end;

      return matchesSearch && matchesStatus && matchesDate && matchesPrice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 140),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildFilterBar(),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.blueAccent,
                tabs: const [
                  Tab(text: 'Active Orders'),
                  Tab(text: 'Disputes'),
                  Tab(text: 'Order History'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveOrdersTab(),
          _buildDisputesTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search Order ID, Buyer or Seller...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(width: 12),
        _buildFilterChip(
          label: _dateRange == null ? 'Date Range' : '${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}',
          icon: Icons.calendar_today_outlined,
          onTap: _selectDateRange,
          isActive: _dateRange != null,
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: 'Price Range',
          icon: Icons.attach_money_rounded,
          onTap: _showPriceFilter,
          isActive: _priceRange.start > 0 || _priceRange.end < 10000,
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            setState(() {
              _searchController.clear();
              _searchQuery = '';
              _statusFilter = 'all';
              _dateRange = null;
              _priceRange = const RangeValues(0, 10000);
            });
          },
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Reset Filters',
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required IconData icon, required VoidCallback onTap, bool isActive = false}) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: isActive ? Colors.white : Colors.black54),
      label: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontSize: 12)),
      backgroundColor: isActive ? Colors.blueAccent : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isActive ? Colors.blueAccent : Colors.black12)),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _showPriceFilter() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('RM ${_priceRange.start.round()} - RM ${_priceRange.end.round()}'),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 10000,
                divisions: 100,
                onChanged: (values) {
                  setDialogState(() => _priceRange = values);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrdersTab() {
    return Consumer<OrderState>(
      builder: (context, orderState, child) {
        final activeOrders = orderState.items
            .where((o) =>
        o.status.toLowerCase() == 'pending' ||
            o.status.toLowerCase() == 'paid' ||
            o.status.toLowerCase() == 'disputed')
            .toList();
        return _buildOrderList(_applyFilters(activeOrders), orderState);
      },
    );
  }

  Widget _buildDisputesTab() {
    return Consumer2<DisputeState, OrderState>(
      builder: (context, disputeState, orderState, child) {
        final openDisputes =
        disputeState.items.where((d) => d.status == 'open').toList();

        if (disputeState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (openDisputes.isEmpty) {
          return const Center(child: Text('No open disputes.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: openDisputes.length,
          itemBuilder: (context, index) {
            final dispute = openDisputes[index];
            final order = orderState.getById(dispute.orderId);

            // Safe substring for ID
            final displayId = dispute.id.length > 8
                ? dispute.id.substring(0, 8)
                : dispute.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dispute #$displayId',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
                            'OPEN DISPUTE',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (order != null)
                      Text('Order ID: ${order.orderNumber}')
                    else
                      Text('Order Ref: ${dispute.orderId}'),
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${dispute.reason}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Description: ${dispute.description}'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (order != null)
                          TextButton.icon(
                            onPressed: () => _viewChatHistory(order),
                            icon: const Icon(Icons.chat_outlined),
                            label: const Text('View Chat History'),
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _showResolveDialog(dispute),
                          child: const Text('Resolve Dispute'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Consumer<OrderState>(
      builder: (context, orderState, child) {
        final historyOrders = orderState.items
            .where((o) =>
        o.status.toLowerCase() == 'handed over' ||
            o.status.toLowerCase() == 'cancelled' ||
            o.status.toLowerCase() == 'completed')
            .toList();
        return _buildOrderList(_applyFilters(historyOrders), orderState);
      },
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, OrderState orderState) {
    if (orderState.isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(child: Text('No orders found.'));
    }

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 800) {
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: orders.length,
          itemBuilder: (context, index) => _buildOrderMobileCard(orders[index]),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                columns: const [
                  DataColumn(label: Text('Order #')),
                  DataColumn(label: Text('Item')),
                  DataColumn(label: Text('Buyer')),
                  DataColumn(label: Text('Seller')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: orders.map((order) {
                  return DataRow(
                    cells: [
                      DataCell(Text(order.orderNumber)),
                      DataCell(
                        Text(
                          order.orderItems.isNotEmpty
                              ? order.orderItems.first.product?.title ?? 'Item'
                              : 'No Item',
                        ),
                      ),
                      DataCell(Text(order.buyer?.name ?? 'Unknown')),
                      DataCell(Text(order.primarySellerName ?? 'Unknown')),
                      DataCell(Text('RM ${order.totalPrice.toStringAsFixed(2)}')),
                      DataCell(_buildStatusBadge(order.status)),
                      DataCell(Text(order.createdAt != null ? DateFormat('yyyy-MM-dd').format(order.createdAt!) : '-')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 20),
                          tooltip: 'View Order Details',
                          onPressed: () => _showAdminOrderDetails(order),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildOrderMobileCard(OrderModel order) {
    return InkWell(
      onTap: () => _showAdminOrderDetails(order),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow('Item', order.orderItems.isNotEmpty ? order.orderItems.first.product?.title ?? 'Item' : 'No Item'),
              _buildDetailRow('Buyer', order.buyer?.name ?? 'Unknown'),
              _buildDetailRow('Seller', order.primarySellerName ?? 'Unknown'),
              _buildDetailRow('Price', 'RM ${order.totalPrice.toStringAsFixed(2)}'),
              _buildDetailRow('Date', order.createdAt != null ? DateFormat('yyyy-MM-dd').format(order.createdAt!) : '-'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.blue;
        break;
      case 'paid':
        color = Colors.teal;
        break;
      case 'handed over':
      case 'completed':
        color = Colors.green;
        break;
      case 'disputed':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showAdminOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Details', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('#${order.orderNumber}', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAdminDetailSection(
                      title: 'Order Status & Date',
                      child: Row(
                        children: [
                          _buildStatusBadge(order.status),
                          const SizedBox(width: 16),
                          Text(order.createdAt != null ? DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt!) : 'Unknown Date'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAdminDetailSection(
                      title: 'Parties Involved',
                      child: Row(
                        children: [
                          Expanded(child: _buildPartyInfo('Buyer', order.buyer?.name ?? 'Unknown', order.buyerId)),
                          const Icon(Icons.compare_arrows_rounded, color: Colors.black26),
                          Expanded(child: _buildPartyInfo('Seller', order.primarySellerName ?? 'Unknown', order.primarySellerId ?? 'Unknown')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAdminDetailSection(
                      title: 'Order Items',
                      child: Column(
                        children: order.orderItems.map((item) => _buildOrderItemTile(item)).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAdminDetailSection(
                      title: 'Handover Information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(Icons.location_on_outlined, 'Location', order.handoverLocation ?? 'TBD'),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.event_outlined, 'Date', order.handoverDate != null ? DateFormat('MMM dd, yyyy HH:mm').format(order.handoverDate!) : 'TBD'),
                          if (order.notes?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.notes_rounded, 'Notes', order.notes!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAdminDetailSection(
                      title: 'Payment Summary',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _buildSummaryRow('Subtotal', 'RM ${order.totalPrice.toStringAsFixed(2)}'),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Total', 'RM ${order.totalPrice.toStringAsFixed(2)}', isBold: true),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Payment Status', order.paymentStatus.toUpperCase(), color: order.paymentStatus.toLowerCase() == 'paid' ? Colors.green : Colors.orange),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _viewChatHistory(order),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Monitor Order Chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDetailSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildPartyInfo(String role, String name, String id) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text('ID: $id', style: const TextStyle(fontSize: 10, color: Colors.black38)),
      ],
    );
  }

  Widget _buildOrderItemTile(OrderItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageHelper.productImage(item.product?.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product?.title ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (item.variant != null) 
                  Text(item.variant!.optionSummary, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('RM ${item.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: 14, color: color)),
      ],
    );
  }

  void _showResolveDialog(DisputeModel dispute) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dispute Reason: ${dispute.reason}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Resolution Notes',
                hintText: 'Explain the decision...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _handleResolve(
                dispute, 'cancelled', notesController.text, context),
            child: const Text('Rule for Buyer (Cancel)'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _handleResolve(
                dispute, 'completed', notesController.text, context),
            child: const Text('Rule for Seller (Complete)'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResolve(DisputeModel dispute, String status, String notes,
      BuildContext context) async {
    try {
      await context.read<DisputeState>().resolveDispute(
        disputeId: dispute.id,
        orderId: dispute.orderId,
        resolutionStatus: status,
        resolutionNotes: notes,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute resolved successfully.')),
        );
        // Refresh orders to reflect the status change
        context.read<OrderState>().fetchAllOrders();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _viewChatHistory(OrderModel order) {
    final productId = order.primaryProductId;
    final buyerId = order.buyerId;
    final sellerId = order.primarySellerId;

    if (productId == null || sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify chat details.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline),
            const SizedBox(width: 12),
            const Expanded(child: Text('Chat Monitoring')),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 600,
          child: FutureBuilder<List<ChatMessageModel>>(
            future: ChatService().getOrCreateConversation(
              productId: productId,
              buyerId: buyerId,
              sellerId: sellerId,
              currentUserId: buyerId,
            ).then((bundle) => bundle.messages),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(child: Text('No messages found for this transaction.'));
              }

              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isBuyer = msg.senderId == buyerId;

                  return Align(
                    alignment: isBuyer ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isBuyer ? Colors.blue.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isBuyer ? Colors.blue.shade100 : Colors.green.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: isBuyer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: [
                          Text(
                            isBuyer ? 'Buyer' : 'Seller',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isBuyer ? Colors.blue : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(msg.messageText),
                          const SizedBox(height: 4),
                          Text(
                            msg.createdAt?.toLocal().toString().substring(0, 16) ?? '',
                            style: const TextStyle(fontSize: 9, color: Colors.black38),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
