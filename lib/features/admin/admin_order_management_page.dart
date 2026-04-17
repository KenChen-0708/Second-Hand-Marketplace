import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/state.dart';
import '../../models/models.dart';

class AdminOrderManagementPage extends StatefulWidget {
  const AdminOrderManagementPage({super.key});

  @override
  State<AdminOrderManagementPage> createState() =>
      _AdminOrderManagementPageState();
}

class _AdminOrderManagementPageState extends State<AdminOrderManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 80),
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

  Widget _buildActiveOrdersTab() {
    return Consumer<OrderState>(
      builder: (context, orderState, child) {
        final activeOrders = orderState.items
            .where((o) =>
                o.status.toLowerCase() == 'pending' ||
                o.status.toLowerCase() == 'paid' ||
                o.status.toLowerCase() == 'disputed')
            .toList();
        return _buildOrderList(activeOrders, orderState);
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

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.orange, width: 1),
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
                    Text('Order ID: ${order?.orderNumber ?? 'Unknown'}'),
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
        return _buildOrderList(historyOrders, orderState);
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
                    DataCell(Text('\$${order.totalPrice.toStringAsFixed(2)}')),
                    DataCell(_buildStatusBadge(order.status)),
                    DataCell(
                      PopupMenuButton<String>(
                        onSelected: (newStatus) =>
                            _updateOrderStatus(order, newStatus),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          const PopupMenuItem(
                            value: 'paid',
                            child: Text('Paid'),
                          ),
                          const PopupMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          const PopupMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled',
                                style: TextStyle(color: Colors.red)),
                          ),
                          const PopupMenuItem(
                            value: 'disputed',
                            child: Text('Disputed',
                                style: TextStyle(color: Colors.orange)),
                          ),
                        ],
                        icon: const Icon(Icons.edit_note_rounded),
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

  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    try {
      await context.read<OrderState>().updateOrderStatus(order.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order ${order.orderNumber} updated to $newStatus')),
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
}
