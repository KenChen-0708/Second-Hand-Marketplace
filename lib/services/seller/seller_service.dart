import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class SellerStats {
  final int activeListings;
  final int itemsSold;
  final int ordersAwaitingAction;
  final double totalEarnings;
  final int unreadChats;

  SellerStats({
    required this.activeListings,
    required this.itemsSold,
    required this.ordersAwaitingAction,
    required this.totalEarnings,
    required this.unreadChats,
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

  Future<SellerStats> getSellerStats(String userId) async {
    try {
      // 1. Fetch products count by status
      final productsResponse = await _supabase
          .from('products')
          .select('id, status')
          .eq('seller_id', userId);

      final products = productsResponse as List;
      final activeListings =
          products.where((p) => p['status'] == 'active').length;
      final itemsSold = products.where((p) => p['status'] == 'sold').length;

      // 2. Fetch orders awaiting action
      // Orders where status is 'pending' AND the user is the seller of at least one item
      final ordersAwaitingActionResponse = await _supabase
          .from('orders')
          .select('id, status, order_items!inner(product_id, products!inner(seller_id))')
          .eq('status', 'pending')
          .eq('order_items.products.seller_id', userId);

      final ordersAwaitingAction = (ordersAwaitingActionResponse as List).length;

      // 3. Fetch total earnings (sum of total_price of orders with status 'completed' where user is seller)
      final completedOrdersResponse = await _supabase
          .from('orders')
          .select('id, total_price, order_items!inner(product_id, products!inner(seller_id))')
          .eq('status', 'completed')
          .eq('order_items.products.seller_id', userId);

      double totalEarnings = 0;
      for (var order in completedOrdersResponse) {
        totalEarnings += (order['total_price'] as num).toDouble();
      }

      // 4. Fetch unread chats (Mock logic or actual if possible)
      // Since chat is mostly mock for now, we'll return a static number or 0
      final unreadChatsCount = 2; // Mock

      return SellerStats(
        activeListings: activeListings,
        itemsSold: itemsSold,
        ordersAwaitingAction: ordersAwaitingAction,
        totalEarnings: totalEarnings,
        unreadChats: unreadChatsCount,
      );
    } catch (e) {
      print('Error fetching seller stats: $e');
      return SellerStats(
        activeListings: 0,
        itemsSold: 0,
        ordersAwaitingAction: 0,
        totalEarnings: 0,
        unreadChats: 0,
      );
    }
  }

  Future<List<SellerNeedAction>> getNeedsAction(String userId) async {
    List<SellerNeedAction> actions = [];

    try {
      // 1. Check for orders needing confirmation
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

      // 2. Check for handovers scheduled today
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

      // 3. Mock unread messages if none
      if (actions.isEmpty) {
        actions.add(SellerNeedAction(
          title: 'Unread Buyer Message',
          description: 'You have a new message regarding your "iPhone 13 Pro" listing.',
          ctaLabel: 'Open Chat',
          actionType: 'open_chat',
          relatedId: 'c1',
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
