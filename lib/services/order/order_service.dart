import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';

class OrderService {
  OrderService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<OrderModel>> createOrder({
    required String buyerId,
    required List<OrderItemModel> orderItems,
    String? handoverLocation,
    DateTime? handoverDate,
    String? notes,
    String status = 'Pending',
    String paymentStatus = 'Pending',
  }) async {
    if (orderItems.isEmpty) {
      throw Exception('Cannot create an order with an empty cart.');
    }

    try {
      final orderNumber = _generateOrderNumber();
      final totalPrice = orderItems.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );

      final insertedOrder = await _supabase
          .from('orders')
          .insert({
            'order_number': orderNumber,
            'buyer_id': buyerId,
            'total_price': totalPrice,
            'status': status,
            'payment_status': paymentStatus,
            'handover_location': handoverLocation,
            'handover_date': handoverDate?.toIso8601String(),
            'notes': notes,
          })
          .select()
          .single();

      final order = OrderModel.fromMap(
        Map<String, dynamic>.from(insertedOrder),
      );

      final orderItemPayload = orderItems
          .map(
            (item) => <String, dynamic>{
              'order_id': order.id,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'subtotal': item.subtotal,
            },
          )
          .toList();

      final insertedOrderItems = await _supabase
          .from('order_items')
          .insert(orderItemPayload)
          .select();

      final normalizedOrder = order.copyWith(
        orderItems: (insertedOrderItems as List)
            .map(
              (item) =>
                  OrderItemModel.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );

      return [normalizedOrder];
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  String _generateOrderNumber() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'ORD-$now';
  }
}
