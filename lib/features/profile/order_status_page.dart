import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../models/mock_data.dart';

class OrderStatusPage extends StatelessWidget {
  final Object? order;
  const OrderStatusPage({super.key, this.order});

  ProductModel? _getProduct(String? productId) {
    if (productId == null) return null;
    try {
      return mockProducts.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    OrderModel? currentOrder = order as OrderModel?;
    bool isHandedOver = currentOrder?.status == 'Completed/Handed Over';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Order Status',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildStatusItem(
                    context,
                    title: 'Payment Successful',
                    subtitle: 'Your payment has been received.',
                    time: 'Just now',
                    isCompleted: true,
                    isLast: false,
                  ),
                  _buildStatusItem(
                    context,
                    title: 'Order Confirmed',
                    subtitle: 'The seller has been notified.',
                    time: 'Just now',
                    isCompleted: true,
                    isLast: false,
                  ),
                  _buildStatusItem(
                    context,
                    title: isHandedOver ? 'Handed Over' : 'Awaiting Handover',
                    subtitle: isHandedOver
                        ? 'You have successfully received the item.'
                        : 'Meet the seller at the agreed location.',
                    time: isHandedOver ? 'Completed' : 'Pending',
                    isCompleted: isHandedOver,
                    isLast: true,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Handover Instructions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Message from buyer: "Meet me at the Library foyer at 2 PM"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (isHandedOver) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          // Navigate to Seller Review page
                          context.push(
                            '/profile/seller-review',
                            extra: _getProduct(currentOrder?.productId),
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(
                            0xFF10B981,
                          ), // Emerald Green
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Rate Seller',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  Widget _buildStatusItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String time,
    required bool isCompleted,
    required bool isLast,
  }) {
    final color = isCompleted ? const Color(0xFF10B981) : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast) Container(width: 2, height: 50, color: color),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCompleted ? Colors.black : Colors.grey,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
