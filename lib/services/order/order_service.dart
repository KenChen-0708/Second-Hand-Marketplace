import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../notification/notification_service.dart';

class OrderService {
  OrderService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client,
      _notificationService = NotificationService(client: client ?? Supabase.instance.client);

  final SupabaseClient _supabase;
  final NotificationService _notificationService;

  Future<List<OrderModel>> createOrder({
    required String buyerId,
    required List<OrderItemModel> orderItems,
    String? handoverLocation,
    DateTime? handoverDate,
    String? notes,
    double additionalFee = 0,
    String status = 'pending',
    String paymentStatus = 'pending',
  }) async {
    if (orderItems.isEmpty) {
      throw Exception('Cannot create an order with an empty cart.');
    }

    try {
      final orderNumber = _generateOrderNumber();
      final itemsTotal = orderItems.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );
      final totalPrice = itemsTotal + additionalFee;

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
              'variant_id': item.variantId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'subtotal': item.subtotal,
            },
          )
          .toList();

      await _supabase.from('order_items').insert(orderItemPayload);

      // 🔥 NOTIFICATION TRIGGERS
      // 1. Notify Buyer
      await _notificationService.createNotification(
        userId: buyerId,
        title: 'Order Placed!',
        message: 'Your order $orderNumber has been placed successfully.',
        type: 'order',
        relatedOrderId: order.id,
      );

      // 2. Notify Sellers (Loop through the original input items which have product data)
      final Set<String> notifiedSellers = {};
      for (var item in orderItems) {
        final sellerId = item.product?.sellerId;
        if (sellerId != null && !notifiedSellers.contains(sellerId)) {
          await _notificationService.createNotification(
            userId: sellerId,
            title: 'Item Sold!',
            message: 'Someone bought your "${item.product!.title}". Check your dashboard.',
            type: 'item_sold',
            relatedOrderId: order.id,
            relatedProductId: item.product!.id,
          );
          notifiedSellers.add(sellerId);
        }
      }

      return [order];
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await _supabase
          .from('orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select('*, buyer_id')
          .single();

      await _notificationService.createNotification(
        userId: response['buyer_id'],
        title: 'Order Updated',
        message: 'Your order status has been updated to: ${status.toUpperCase()}.',
        type: 'order',
        relatedOrderId: orderId,
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      final buyerResponse = await _supabase
          .from('orders')
          .select(
            '*, buyer:users!orders_buyer_id_fkey(*), order_items(*, products(*, seller:users(*), variations:product_variants(*, attributes:product_variant_attributes(*))), variant:product_variants(*, attributes:product_variant_attributes(*)))',
          )
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);

      final sellerResponse = await _supabase
          .from('orders')
          .select(
            '*, buyer:users!orders_buyer_id_fkey(*), order_items!inner(*, products!inner(*, seller:users(*), variations:product_variants(*, attributes:product_variant_attributes(*))), variant:product_variants(*, attributes:product_variant_attributes(*)))',
          )
          .eq('order_items.products.seller_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> combinedRaw = [...(buyerResponse as List), ...(sellerResponse as List)];
      final Map<String, dynamic> uniqueOrders = {};
      for (var o in combinedRaw) {
        uniqueOrders[o['id'].toString()] = o;
      }

      final List<OrderModel> orders = uniqueOrders.values
          .map((order) => OrderModel.fromMap(_resolveOrderImageFields(
                Map<String, dynamic>.from(order),
              )))
          .toList();

      orders.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      return orders;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  Future<List<OrderModel>> getBuyerOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, buyer:users!orders_buyer_id_fkey(*), order_items(*, products(*, seller:users(*), variations:product_variants(*, attributes:product_variant_attributes(*))), variant:product_variants(*, attributes:product_variant_attributes(*)))',
          )
          .eq('buyer_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((order) => OrderModel.fromMap(_resolveOrderImageFields(
                Map<String, dynamic>.from(order as Map),
              )))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch purchase history: $e');
    }
  }

  Future<OrderModel> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, buyer:users!orders_buyer_id_fkey(*), order_items(*, products(*, seller:users(*), variations:product_variants(*, attributes:product_variant_attributes(*))), variant:product_variants(*, attributes:product_variant_attributes(*)))',
          )
          .eq('id', orderId)
          .single();

      return OrderModel.fromMap(
        _resolveOrderImageFields(Map<String, dynamic>.from(response)),
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch order details: $e');
    }
  }

  Future<List<OrderModel>> getSellerOrders(String sellerId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, buyer:users!orders_buyer_id_fkey(*), order_items!inner(*, products!inner(*, seller:users(*), variations:product_variants(*, attributes:product_variant_attributes(*))), variant:product_variants(*, attributes:product_variant_attributes(*)))',
          )
          .eq('order_items.products.seller_id', sellerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((order) => OrderModel.fromMap(_resolveOrderImageFields(
                Map<String, dynamic>.from(order as Map),
              )))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch seller orders: $e');
    }
  }

  Future<void> reportOrderIssue({
    required String orderId,
    required String reporterId,
    required String accusedId,
    required String reason,
    required String description,
  }) async {
    try {
      await _supabase.from('disputes').insert({
        'order_id': orderId,
        'reporter_id': reporterId,
        'accused_id': accusedId,
        'reason': reason,
        'description': description,
        'status': 'open',
      });

      await updateOrderStatus(orderId, 'disputed');
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to report this issue: $e');
    }
  }

  Future<List<OrderModel>> getAllOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, buyer:users!orders_buyer_id_fkey(*), order_items(*, products(*, seller:users(*), variations:product_variants(*, attributes:product_variant_attributes(*))), variant:product_variants(*, attributes:product_variant_attributes(*)))',
          )
          .order('created_at', ascending: false);

      return (response as List)
          .map((order) => OrderModel.fromMap(_resolveOrderImageFields(
                Map<String, dynamic>.from(order),
              )))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch all orders: $e');
    }
  }

  String _generateOrderNumber() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'ORD-$now';
  }

  Map<String, dynamic> _resolveOrderImageFields(Map<String, dynamic> order) {
    final rawItems = order['order_items'];
    if (rawItems is! List) {
      return order;
    }

    return {
      ...order,
      'order_items': rawItems.map((rawItem) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final rawProduct = item['products'];
        if (rawProduct is! Map) {
          return item;
        }

        final product = Map<String, dynamic>.from(rawProduct);
        final resolvedImages = ImageHelper.resolveProductImageUrls(
          product['image_urls'],
        );
        final resolvedImageUrl =
            ImageHelper.resolveProductImageUrl(
              product['image_url']?.toString(),
              fallbackToDefault: false,
            ) ??
            (resolvedImages.isNotEmpty ? resolvedImages.first : null);

        return {
          ...item,
          'products': {
            ...product,
            'image_url': resolvedImageUrl,
            'image_urls': resolvedImages,
          },
        };
      }).toList(),
    };
  }
}
