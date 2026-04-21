import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class SellerStats {
  final int activeListings;
  final int itemsSold;
  final int ordersAwaitingAction;
  final double totalEarnings;
  final int unreadChats;
  final double averageRating;
  final int totalReviews;

  SellerStats({
    required this.activeListings,
    required this.itemsSold,
    required this.ordersAwaitingAction,
    required this.totalEarnings,
    required this.unreadChats,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });
}

class SellerNeedAction {
  final String title;
  final String description;
  final String ctaLabel;
  final String actionType; // e.g., 'confirm_order', 'open_chat', etc.
  final String? relatedId;

  SellerNeedAction({
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.actionType,
    this.relatedId,
  });
}

class SellerService {
  SellerService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<SellerProfileModel?> fetchPublicProfile(String userId) async {
    try {
      final response = await _supabase
          .from('seller_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) return null;
      return SellerProfileModel.fromMap(response);
    } catch (e) {
      print('Error fetching public seller profile: $e');
      return null;
    }
  }

  Future<List<ReviewModel>> fetchSellerReviews(String sellerId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('*, reviewer:users!reviews_reviewer_id_fkey(*)')
          .eq('reviewee_id', sellerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((r) => ReviewModel.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      print('Error fetching seller reviews: $e');
      return [];
    }
  }

  Future<SellerStats> getSellerStats(String userId) async {
    int activeCount = 0;
    int soldCount = 0;
    double avgRating = 0.0;
    int reviewCount = 0;
    double earnings = 0.0;

    try {
      final String uid = userId.trim();

      // 1. Fetch products count
      final pResponse = await _supabase
          .from('products')
          .select('status')
          .eq('seller_id', uid);
      
      if (pResponse != null) {
        final pList = (pResponse as List);
        for (var p in pList) {
          final s = (p['status'] as String? ?? '').toLowerCase();
          if (s == 'active') activeCount++;
          // Manual product status "sold" also counts
          if (s == 'sold') soldCount++;
        }
      }

      // 2. Fetch reviews directly
      final rResponse = await _supabase
          .from('reviews')
          .select('rating')
          .eq('reviewee_id', uid);
      
      if (rResponse != null) {
        final rList = (rResponse as List);
        reviewCount = rList.length;
        if (reviewCount > 0) {
          double sum = 0;
          for (var r in rList) {
            sum += (r['rating'] as num?)?.toDouble() ?? 0.0;
          }
          avgRating = sum / reviewCount;
        }
      }

      // 3. Fetch Sold Items from Order History
      // We query order_items and join both orders and products
      final oResponse = await _supabase
          .from('order_items')
          .select('quantity, unit_price, orders!inner(status), products!inner(seller_id)')
          .eq('products.seller_id', uid);

      if (oResponse != null) {
        int orderSoldItems = 0;
        for (var item in (oResponse as List)) {
          final orderData = item['orders'];
          String orderStatus = '';
          
          if (orderData is Map) {
            orderStatus = (orderData['status'] as String? ?? '').toLowerCase();
          } else if (orderData is List && orderData.isNotEmpty) {
            orderStatus = (orderData[0]['status'] as String? ?? '').toLowerCase();
          }

          if (orderStatus == 'completed') {
            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
            orderSoldItems += qty;
            earnings += (qty * price);
          }
        }
        
        // Merge counts: products marked as 'sold' + items in 'completed' orders
        // Note: Usually a completed order item refers to a product that might 
        // or might not have its status updated to 'sold' in the products table.
        // We take the max or sum depending on how your app marks things.
        // Let's take the items from completed orders as the source of truth for volume.
        if (orderSoldItems > 0) {
           // If we have items in completed orders, that's our true sold count
           soldCount = orderSoldItems;
        }
      }

    } catch (e) {
      print('DEBUG: getSellerStats error: $e');
    }

    return SellerStats(
      activeListings: activeCount,
      itemsSold: soldCount,
      ordersAwaitingAction: 0,
      totalEarnings: earnings,
      unreadChats: 0,
      averageRating: avgRating,
      totalReviews: reviewCount,
    );
  }

  Future<List<SellerNeedAction>> getNeedsAction(String userId) async {
    List<SellerNeedAction> actions = [];
    try {
      final pendingOrders = await _supabase
          .from('orders')
          .select('id, order_number, order_items!inner(product_id, products!inner(title, seller_id))')
          .eq('status', 'pending')
          .eq('order_items.products.seller_id', userId);

      for (var order in pendingOrders) {
        final productName = order['order_items'][0]['products']['title'];
        actions.add(SellerNeedAction(
          title: 'Order Confirmation Needed',
          description: 'A buyer wants to purchase "$productName".',
          ctaLabel: 'Confirm Order',
          actionType: 'confirm_order',
          relatedId: order['id'],
        ));
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final todayHandovers = await _supabase
          .from('orders')
          .select('id, order_number, handover_location, order_items!inner(product_id, products!inner(title, seller_id))')
          .eq('status', 'pending_handover')
          .eq('order_items.products.seller_id', userId)
          .gte('handover_date', startOfDay)
          .lte('handover_date', endOfDay);

      for (var order in todayHandovers) {
        final productName = order['order_items'][0]['products']['title'];
        actions.add(SellerNeedAction(
          title: 'Handover Scheduled Today',
          description: 'Meet the buyer for "$productName" at ${order['handover_location']}.',
          ctaLabel: 'Mark Ready',
          actionType: 'mark_ready',
          relatedId: order['id'],
        ));
      }
    } catch (e) {
      print('Error fetching needs action: $e');
    }
    return actions;
  }

  Future<Map<String, List<OrderModel>>> getOrdersSummary(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, buyer:users!orders_buyer_id_fkey(*), order_items!inner(*, products!inner(*, seller:users(*)))')
          .eq('order_items.products.seller_id', userId)
          .order('created_at', ascending: false);

      final List<OrderModel> orders = (response as List)
          .map((o) => OrderModel.fromMap(Map<String, dynamic>.from(o)))
          .toList();

      return {
        'awaiting_confirmation': orders.where((o) => o.status.toLowerCase() == 'pending').toList(),
        'ready_for_handover': orders.where((o) => o.status.toLowerCase() == 'pending_handover').toList(),
        'completed': orders.where((o) => o.status.toLowerCase() == 'completed').toList(),
        'cancelled': orders.where((o) => o.status.toLowerCase() == 'cancelled' || o.status.toLowerCase() == 'disputed').toList(),
      };
    } catch (e) {
      print('Error fetching orders summary: $e');
      return {
        'awaiting_confirmation': [],
        'ready_for_handover': [],
        'completed': [],
        'cancelled': [],
      };
    }
  }

  Future<List<ProductModel>> getListings(String userId) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('seller_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((p) => ProductModel.fromMap(Map<String, dynamic>.from(p)))
          .toList();
    } catch (e) {
      print('Error fetching listings: $e');
      return [];
    }
  }
}
