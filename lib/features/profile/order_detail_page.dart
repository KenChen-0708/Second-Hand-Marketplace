import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../../state/state.dart';
import '../../services/chat/chat_service.dart';
import '../../services/review/review_service.dart';

class OrderStatusPage extends StatefulWidget {
  final Object? order;
  const OrderStatusPage({super.key, this.order});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  OrderModel? _currentOrder;
  ReviewModel? _existingReview;
  bool _isReloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.order is OrderModel) {
      _currentOrder = widget.order as OrderModel;
      _checkExistingReview();
    }
  }

  Future<void> _checkExistingReview() async {
    final order = _currentOrder;
    final userState = context.read<UserState>();
    final currentUserId = userState.currentUser?.id;

    if (order != null && currentUserId != null && order.status.toLowerCase() == 'completed') {
      final reviewService = ReviewService();
      final review = await reviewService.fetchReviewForOrder(order.id, currentUserId);
      if (mounted) {
        setState(() {
          _existingReview = review;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final currentOrder = _currentOrder!;
    final userState = context.read<UserState>();
    final currentUserId = userState.currentUser?.id ?? '';
    final isBuyer = currentOrder.isBuyer(currentUserId);

    final statusInfo = _getStatusDisplayInfo(currentOrder.status);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Order #${currentOrder.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHelpSheet(context, currentOrder, isBuyer),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _reloadOrder,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildStatusHeader(context, statusInfo),
                  _buildContextualAlert(context, currentOrder, isBuyer),
                  _buildSection(
                    title: 'Order Tracking',
                    child: _buildTimeline(currentOrder, statusInfo),
                  ),
                  _buildSection(
                    title: 'Purchase Summary',
                    child: Column(
                      children: [
                        if (currentOrder.orderItems.isEmpty)
                          Text(
                            'No items were found for this order.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          )
                        else
                          ...currentOrder.orderItems.map((item) => _buildProductItem(context, item)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                        _buildSummaryRow('Subtotal', '\$${(currentOrder.totalPrice).toStringAsFixed(2)}'),
                        _buildSummaryRow('Escrow Protection', 'Included', isGreen: true),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Total', '\$${(currentOrder.totalPrice).toStringAsFixed(2)}', isTotal: true),
                      ],
                    ),
                  ),
                  _buildSection(
                    title: 'Handover Details',
                    child: Column(
                      children: [
                        _buildInfoField('Location', currentOrder.handoverLocation ?? 'TBD', icon: Icons.location_on_rounded, color: Colors.blue),
                        const SizedBox(height: 16),
                        _buildInfoField('Agreed Time', currentOrder.handoverDate != null ? dateFormat.format(currentOrder.handoverDate!) : 'To be scheduled', icon: Icons.calendar_today_rounded, color: Colors.indigo),
                        if (currentOrder.notes?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 16),
                          _buildInfoField('Special Instructions', currentOrder.notes!, icon: Icons.info_outline_rounded, color: Colors.amber),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildRoleAwareActions(context, currentOrder, isBuyer),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          if (_isReloading)
            Container(
              color: Colors.black.withValues(alpha: 0.06),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _reloadOrder() async {
    final orderId = _currentOrder?.id;
    if (orderId == null) {
      return;
    }

    setState(() => _isReloading = true);
    final updatedOrder = await context.read<OrderState>().fetchOrderById(orderId);
    if (!mounted) {
      return;
    }
    setState(() {
      if (updatedOrder != null) {
        _currentOrder = updatedOrder;
      }
      _isReloading = false;
    });
    await _checkExistingReview();
  }

  Future<void> _reloadAfterAction(String successMessage) async {
    await _reloadOrder();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }

  Widget _buildStatusHeader(BuildContext context, _StatusInfo info) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: info.color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(info.icon, color: info.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(info.explanation, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualAlert(BuildContext context, OrderModel order, bool isBuyer) {
    final status = order.status.toLowerCase();
    String message = '';
    IconData icon = Icons.info_outline_rounded;
    Color color = Colors.blue;

    if (status == 'pending') {
      message = isBuyer ? 'Wait for seller to confirm your order.' : 'Please confirm this order to proceed with handover.';
    } else if (status == 'paid') {
      message = isBuyer ? 'Payment protected until you confirm receipt.' : 'Ready for handover. Coordinate meet-up in chat.';
      icon = Icons.security_rounded;
      color = Colors.green;
    } else if (status == 'pending_handover') {
      message = isBuyer ? 'Bring your confirmation code and inspect item before confirming.' : 'Ensure buyer inspects the item before finalizing.';
      icon = Icons.handshake_rounded;
      color = Colors.indigo;
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildTimeline(OrderModel order, _StatusInfo currentInfo) {
    final status = order.status.toLowerCase();
    final steps = [
      {'title': 'Order Placed', 'subtitle': 'Confirmation sent', 'key': 'pending'},
      {'title': 'Paid', 'subtitle': 'Funds held in escrow', 'key': 'paid'},
      {'title': 'Handover Scheduled', 'subtitle': 'Ready for meet-up', 'key': 'pending_handover'},
      {'title': 'Completed', 'subtitle': 'Transaction finished', 'key': 'completed'},
    ];

    int currentStepIndex = 0;
    if (status == 'paid') currentStepIndex = 1;
    else if (status == 'pending_handover') currentStepIndex = 2;
    else if (status == 'completed') currentStepIndex = 3;

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isCompleted = index <= currentStepIndex;
        final isCurrent = index == currentStepIndex;
        return _StatusItem(
          title: step['title']!,
          subtitle: isCurrent ? currentInfo.explanation : step['subtitle']!,
          time: index == 0 ? order.createdAt : (isCurrent ? order.updatedAt : null),
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: index == steps.length - 1,
        );
      }),
    );
  }

  Widget _buildRoleAwareActions(BuildContext context, OrderModel order, bool isBuyer) {
    final status = order.status.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (status == 'pending_handover') ...[
            if (isBuyer) _buildPrimaryAction('Confirm Received', Icons.check_circle_rounded, Colors.green, () => _showConfirmReceipt(context, order))
            else _buildPrimaryAction('Handover Done', Icons.handshake_rounded, Colors.indigo, () => _showHandoverConfirmation(context, order)),
            const SizedBox(height: 12),
          ],
          if (status == 'pending' && !isBuyer) ...[
            _buildPrimaryAction('Confirm Order', Icons.check_circle_rounded, Colors.green, () => _updateStatus(context, order, 'paid')),
            const SizedBox(height: 12),
          ],
          if (status == 'paid' && !isBuyer) ...[
            _buildPrimaryAction('Mark Ready for Handover', Icons.check_circle_rounded, Colors.green, () => _updateStatus(context, order, 'pending_handover')),
            const SizedBox(height: 12),
          ],
          if (status == 'completed' && isBuyer) ...[
            if (_existingReview == null)
              _buildPrimaryAction('Leave Review', Icons.star_rounded, Colors.amber[700]!, () => _navigateToReview(context, order))
            else
              _buildDisabledAction('Review Submitted', Icons.star_rounded),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: _buildSecondaryAction('Chat', Icons.chat_bubble_rounded, Colors.blue, () => _navigateToChat(context, order))),
              const SizedBox(width: 12),
              if (status != 'completed' && status != 'cancelled')
                Expanded(child: _buildSecondaryAction('Cancel', Icons.cancel_rounded, Colors.grey[700]!, () => _showCancelConfirmation(context, order), isDestructive: true))
              else
                Expanded(child: _buildSecondaryAction('Profile', Icons.person_rounded, Colors.blue, () => _navigateToProfile(context, order, isBuyer))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildDisabledAction(String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: null,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.grey[600],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildSecondaryAction(String label, IconData icon, Color color, VoidCallback onPressed, {bool isDestructive = false}) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        foregroundColor: isDestructive ? Colors.red : color,
        backgroundColor: (isDestructive ? Colors.red : color).withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildProductItem(BuildContext context, OrderItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ImageHelper.productImage(
              item.product?.imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product?.title ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)), child: Text((item.product?.condition ?? 'good').replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[700]))),
                const SizedBox(height: 8),
                Text('${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Flexible(
            child: Text(
              '\$${item.subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPhotoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 32),
    );
  }

  Widget _buildInfoField(String label, String value, {required IconData icon, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500, color: isTotal ? Colors.black : Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: isTotal ? 22 : 14, fontWeight: FontWeight.w900, color: (isTotal || isGreen) ? const Color(0xFF10B981) : Colors.black)),
        ],
      ),
    );
  }

  _StatusInfo _getStatusDisplayInfo(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return _StatusInfo(label: 'Awaiting Confirmation', explanation: 'Seller has not prepared the item yet', color: Colors.orange, icon: Icons.hourglass_empty_rounded);
      case 'paid': return _StatusInfo(label: 'Paid · Ready to Ship', explanation: 'Payment confirmed, funds in escrow', color: Colors.blue, icon: Icons.payments_outlined);
      case 'pending_handover': return _StatusInfo(label: 'Ready for Handover', explanation: 'It\'s time to meet up!', color: Colors.indigo, icon: Icons.handshake_outlined);
      case 'completed': return _StatusInfo(label: 'Completed', explanation: 'Transaction finished successfully', color: const Color(0xFF10B981), icon: Icons.check_circle_outline_rounded);
      case 'cancelled': return _StatusInfo(label: 'Cancelled', explanation: 'This order was cancelled', color: Colors.grey, icon: Icons.cancel_outlined);
      case 'disputed': return _StatusInfo(label: 'Disputed', explanation: 'Under investigation', color: Colors.redAccent, icon: Icons.gavel_rounded);
      default: return _StatusInfo(label: status, explanation: '', color: Colors.grey, icon: Icons.info_outline_rounded);
    }
  }

  void _showHelpSheet(BuildContext context, OrderModel order, bool isBuyer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need Help?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _buildHelpItem(Icons.security_rounded, 'Payment Protection', 'Your funds are held safely until you confirm receipt.'),
            _buildHelpItem(Icons.handshake_rounded, 'Handover Safety', 'Meet in public places. Inspect item before confirming.'),
            const Divider(height: 32),
            _buildHelpItem(Icons.report_problem_rounded, 'Something wrong?', 'If the item is not as described or you have issues with the other party, let us know.'),
            const SizedBox(height: 12),
            _buildSecondaryAction('Report Issue', Icons.report_problem_rounded, Colors.orange[800]!, () {
              Navigator.pop(context);
              _handleReport(context, order);
            }),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Got it')),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12))])),
        ],
      ),
    );
  }

  Future<void> _navigateToChat(BuildContext context, OrderModel order) async {
    final userState = context.read<UserState>();
    final currentUserId = userState.currentUser?.id ?? '';
    final isBuyer = order.isBuyer(currentUserId);

    if (order.orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order has no product to chat about.')),
      );
      return;
    }

    final productId = order.orderItems.first.productId;
    final otherUserId = isBuyer ? order.primarySellerId : order.buyerId;

    if (otherUserId == null) return;

    try {
      final chatService = ChatService();
      final bundle = await chatService.getOrCreateConversation(
        productId: productId,
        buyerId: isBuyer ? currentUserId : order.buyerId,
        sellerId: isBuyer ? otherUserId : currentUserId,
        currentUserId: currentUserId,
      );

      if (context.mounted) {
        context.push('/chat/${bundle.conversation.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
      }
    }
  }

  void _navigateToReview(BuildContext context, OrderModel order) async {
    if (order.orderItems.isEmpty) return;
    final item = order.orderItems.first;
    await context.push('/profile/seller-review', extra: {
      'product': item.product,
      'orderId': order.id,
    });
    if (mounted) {
      _checkExistingReview();
    }
  }

  void _navigateToProfile(BuildContext context, OrderModel order, bool isBuyer) {
    final otherUserId = isBuyer ? order.primarySellerId : order.buyerId;
    if (otherUserId != null) {
      context.push('/seller/$otherUserId');
    }
  }

  void _showCancelConfirmation(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder(context, order);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context, OrderModel order) async {
    try {
      await context.read<OrderState>().updateOrderStatus(order.id, 'cancelled');

      if (context.mounted) {
        await _reloadAfterAction('Order cancelled successfully');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
      }
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    OrderModel order,
    String status,
  ) async {
    try {
      await context.read<OrderState>().updateOrderStatus(order.id, status);
      if (context.mounted) {
        await _reloadAfterAction(
          'Order updated to ${status.replaceAll('_', ' ')}',
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

  void _handleReport(BuildContext context, OrderModel order) {
    final reasonController = TextEditingController();
    final descriptionController = TextEditingController();
    final userState = context.read<UserState>();
    final currentUserId = userState.currentUser?.id ?? '';
    final isBuyer = order.isBuyer(currentUserId);
    final accusedId = isBuyer ? order.primarySellerId : order.buyerId;

    if (currentUserId.isEmpty || accusedId == null || accusedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to report this order right now.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Issue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Item not as described',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'Tell support what happened',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final reason = reasonController.text.trim();
                final description = descriptionController.text.trim();
                if (reason.isEmpty || description.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in both fields.')),
                  );
                  return;
                }

                try {
                  await context.read<OrderState>().reportOrderIssue(
                        orderId: order.id,
                        reporterId: currentUserId,
                        accusedId: accusedId,
                        reason: reason,
                        description: description,
                      );
                  if (context.mounted) {
                    Navigator.pop(sheetContext);
                    await _reloadAfterAction('Report submitted to support.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to submit report: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.report_problem_rounded),
              label: const Text('Submit Report'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      reasonController.dispose();
      descriptionController.dispose();
    });
  }

  void _showConfirmReceipt(BuildContext context, OrderModel order) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Confirm Receipt?'), content: const Text('Only confirm if you have received and inspected the item. This will release the payment to the seller.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not yet')), ElevatedButton(onPressed: () { Navigator.pop(context); _updateStatus(context, order, 'completed'); }, child: const Text('Confirm'))]));
  }

  void _showHandoverConfirmation(BuildContext context, OrderModel order) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Handover Done?'), content: const Text('Confirm that you have handed the item to the buyer.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { Navigator.pop(context); _updateStatus(context, order, 'completed'); }, child: const Text('Confirm'))]));
  }
}

class _StatusItem extends StatelessWidget {
  final String title, subtitle;
  final DateTime? time;
  final bool isCompleted, isCurrent, isLast;
  const _StatusItem({required this.title, required this.subtitle, required this.time, required this.isCompleted, required this.isCurrent, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? const Color(0xFF10B981) : Colors.grey[300]!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(color: isCurrent ? Colors.white : (isCompleted ? color : Colors.white), shape: BoxShape.circle, border: Border.all(color: color, width: isCurrent ? 6 : 2), boxShadow: isCurrent ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)] : null), child: isCompleted && !isCurrent ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
              if (!isLast) Expanded(child: Container(width: 2, color: color, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isCompleted ? Colors.black : Colors.grey[400])), const Spacer(), if (time != null) Text(DateFormat('MMM dd, HH:mm').format(time!), style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold))]),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: isCurrent ? Colors.black87 : Colors.grey[500], fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusInfo {
  final String label, explanation;
  final Color color;
  final IconData icon;
  _StatusInfo({required this.label, required this.explanation, required this.color, required this.icon});
}
