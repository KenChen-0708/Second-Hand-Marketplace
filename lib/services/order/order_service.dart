import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';

class OrderService {
  OrderService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<OrderModel>> createOrder({
    required String buyerId,
    required List<OrderItemModel> orderItems,
    String? paymentMethod,
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
      final payload = orderItems
          .map(
            (item) => <String, dynamic>{
              'buyer_id': buyerId,
              'seller_id': item.sellerId,
              'product_id': item.productId,
              'quantity': item.quantity,
              'total_price': item.totalPrice,
              'order_number': orderNumber,
              'status': status,
              'payment_method': paymentMethod,
              'payment_status': paymentStatus,
              'handover_location': handoverLocation,
              'handover_date': handoverDate?.toIso8601String(),
              'notes': notes,
            },
          )
          .toList();

      final data = await _supabase.from('orders').insert(payload).select();
      return (data as List)
          .map(
            (item) =>
                OrderModel.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
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
