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
    String status = 'pending',
    String paymentStatus = 'pending',
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

  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      // For a marketplace, a user can be both a buyer and a seller.
      // We fetch orders where the user is the buyer OR where the user is the seller of at least one item.
      
      // 1. Fetch orders as buyer
      final buyerResponse = await _supabase
          .from('orders')
          .select('*, buyer:users!orders_buyer_id_fkey(*), order_items(*, products(*, seller:users(*)))')
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);

      // 2. Fetch orders where any item belongs to the user (seller)
      final sellerResponse = await _supabase
          .from('orders')
          .select('*, buyer:users!orders_buyer_id_fkey(*), order_items!inner(*, products!inner(*, seller:users(*)))')
          .eq('order_items.products.seller_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> combinedRaw = [...(buyerResponse as List), ...(sellerResponse as List)];
      
      // Remove duplicates by ID
      final Map<String, dynamic> uniqueOrders = {};
      for (var o in combinedRaw) {
        uniqueOrders[o['id'].toString()] = o;
      }

      final List<OrderModel> orders = uniqueOrders.values
          .map((order) => OrderModel.fromMap(Map<String, dynamic>.from(order)))
          .toList();

      // Sort by date again after merging
      orders.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

      return orders;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  Future<List<OrderModel>> getAllOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, buyer:users!orders_buyer_id_fkey(*), order_items(*, products(*, seller:users(*)))')
          .order('created_at', ascending: false);

      return (response as List)
          .map((order) => OrderModel.fromMap(Map<String, dynamic>.from(order)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch all orders: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': status})
          .eq('id', orderId);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  String _generateOrderNumber() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'ORD-$now';
  }
}
