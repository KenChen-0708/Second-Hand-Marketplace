import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/auth/auth_service.dart';
import '../../services/chat/chat_service.dart';
import '../../services/seller/seller_service.dart';
import '../chat/chat_models.dart';
import '../../shared/utils/image_helper.dart';

class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({super.key});

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  final SellerService _sellerService = SellerService();
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();

  bool _isLoading = true;
  SellerStats? _stats;
  List<SellerNeedAction> _needsAction = [];
  Map<String, List<OrderModel>> _ordersSummary = {};
  List<ProductModel> _listings = [];
  List<ChatConversationBundle> _recentConversations = [];
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final email = _authService.supabase.auth.currentUser?.email;
      if (email != null) {
        _currentUser = await _authService.fetchProfileByEmail(email);
        final userId = _currentUser!.id;

        final results = await Future.wait([
          _sellerService.getSellerStats(userId),
          _sellerService.getNeedsAction(userId),
          _sellerService.getOrdersSummary(userId),
          _sellerService.getListings(userId),
          _chatService.fetchUserConversations(userId: userId),
        ]);

        if (mounted) {
          setState(() {
            _stats = results[0] as SellerStats;
            _needsAction = results[1] as List<SellerNeedAction>;
            _ordersSummary = results[2] as Map<String, List<OrderModel>>;
            _listings = results[3] as List<ProductModel>;
            _recentConversations = results[4] as List<ChatConversationBundle>;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          slivers: [
            // ── Header Section ──────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(context, primaryColor),
            ),

            // ── Main Content ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),

                  // 1. Summary Cards
                  _buildSummaryCards(context),

                  const SizedBox(height: 32),

                  // 2. Needs Action Section
                  if (_needsAction.isNotEmpty) ...[
                    _buildSectionTitle('Needs Action', urgency: true),
                    const SizedBox(height: 12),
                    ..._needsAction.map((action) => _buildActionCard(context, action)),
                    const SizedBox(height: 32),
                  ],

                  // 3. Upcoming Handovers
                  _buildUpcomingHandovers(context),

                  const SizedBox(height: 32),

                  // 4. Recent Orders
                  _buildRecentOrders(context),

                  const SizedBox(height: 32),

                  // 5. My Listings Overview
                  _buildListingsOverview(context),

                  const SizedBox(height: 32),

                  // 6. Earnings & Performance
                  _buildEarningsAndPerformance(context, primaryColor),

                  const SizedBox(height: 32),

                  // 7. Recent Buyer Chats
                  _buildRecentChats(context),

                  const SizedBox(height: 48),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sell'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Listing'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    final String avatarUrl = ImageHelper.resolveProfileImageUrl(_currentUser?.avatarUrl, name: _currentUser?.name);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${_currentUser?.name ?? "Seller"}! 👋',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'Verified Seller',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Joined Oct 2025',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(avatarUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - 16) / 2;
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                context,
                'Active Listings',
                _stats?.activeListings.toString() ?? '0',
                Icons.inventory_2_outlined,
                Colors.blue,
                cardWidth,
              ),
              _buildStatCard(
                context,
                'Items Sold',
                _stats?.itemsSold.toString() ?? '0',
                Icons.shopping_bag_outlined,
                Colors.green,
                cardWidth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                context,
                'Awaiting Action',
                _stats?.ordersAwaitingAction.toString() ?? '0',
                Icons.notification_important_outlined,
                Colors.orange,
                cardWidth,
                highlight: (_stats?.ordersAwaitingAction ?? 0) > 0,
              ),
              _buildStatCard(
                context,
                'Total Earnings',
                '\$${_stats?.totalEarnings.toStringAsFixed(0) ?? "0"}',
                Icons.account_balance_wallet_outlined,
                Colors.purple,
                cardWidth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            context,
            'Unread Chats',
            _stats?.unreadChats.toString() ?? '0',
            Icons.chat_bubble_outline_rounded,
            Colors.teal,
            constraints.maxWidth,
          ),
        ],
      );
    });
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    double width, {
    bool highlight = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: highlight ? Border.all(color: color.withValues(alpha: 0.5), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool urgency = false, String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            if (urgency) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, SellerNeedAction action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  action.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              if (action.actionType == 'open_chat') {
                 context.push('/chat/${action.relatedId}');
              } else {
                 context.push('/profile/orders');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              action.ctaLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingHandovers(BuildContext context) {
    final handovers = _ordersSummary['ready_for_handover'] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Upcoming Handovers'),
        const SizedBox(height: 12),
        if (handovers.isEmpty)
          _buildEmptyState('No scheduled handovers', Icons.calendar_today_outlined)
        else
          ...handovers.map((order) => _buildHandoverCard(context, order)),
      ],
    );
  }

  Widget _buildHandoverCard(BuildContext context, OrderModel order) {
    final dateStr = order.handoverDate != null 
        ? DateFormat('MMM dd, hh:mm a').format(order.handoverDate!)
        : 'TBD';
        
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handshake_outlined, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderItems.isNotEmpty 
                          ? order.orderItems[0].product?.title ?? 'Product'
                          : 'Order #${order.orderNumber.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'With ${order.buyer?.name ?? "Buyer"}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.handoverLocation ?? 'No location',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/chat/${order.id}'), // Simplified for demo
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Message Buyer', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/profile/orders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Mark Complete', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Recent Orders', actionLabel: 'View All', onAction: () => context.push('/profile/orders')),
        const SizedBox(height: 12),
        _buildOrderCategoryTab(),
      ],
    );
  }

  Widget _buildOrderCategoryTab() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                ],
              ),
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Ready'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: TabBarView(
                children: [
                  _buildOrderList(_ordersSummary['awaiting_confirmation'] ?? []),
                  _buildOrderList(_ordersSummary['ready_for_handover'] ?? []),
                  _buildOrderList(_ordersSummary['completed'] ?? []),
                  _buildOrderList(_ordersSummary['cancelled'] ?? []),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState('No orders in this category', Icons.shopping_basket_outlined);
    }
    return ListView.builder(
      itemCount: orders.length > 3 ? 3 : orders.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final order = orders[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            order.orderItems.isNotEmpty ? order.orderItems[0].product?.title ?? 'Product' : 'Order',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('Buyer: ${order.buyer?.name ?? "Unknown"}', style: const TextStyle(fontSize: 11)),
          trailing: Text(
            '\$${order.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
          ),
          onTap: () => context.push('/profile/orders'),
        );
      },
    );
  }

  Widget _buildListingsOverview(BuildContext context) {
    final active = _listings.where((p) => p.status == 'active').toList();
    final sold = _listings.where((p) => p.status == 'sold').toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('My Listings', actionLabel: 'Manage All', onAction: () => context.push('/profile/listings')),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildListingSummaryCard('Active', active.length, Colors.blue),
              _buildListingSummaryCard('Sold', sold.length, Colors.green),
              _buildListingSummaryCard('Drafts', 0, Colors.grey),
              _buildListingSummaryCard('Needs Attention', 0, Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (active.isNotEmpty) ...[
           const Text('Active Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
           const SizedBox(height: 12),
           SizedBox(
             height: 160,
             child: ListView.builder(
               scrollDirection: Axis.horizontal,
               itemCount: active.length,
               itemBuilder: (context, index) {
                 final product = active[index];
                 return _buildCompactProductCard(product);
               },
             ),
           ),
        ],
      ],
    );
  }

  Widget _buildListingSummaryCard(String label, int count, Color color) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactProductCard(ProductModel product) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ImageHelper.productImage(product.imageUrl, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsAndPerformance(BuildContext context, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Earnings & Performance'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPerformanceMetric('Average Rating', '4.9', Icons.star_rounded, Colors.orange),
                  _buildPerformanceMetric('Response Rate', '98%', Icons.flash_on_rounded, Colors.blue),
                ],
              ),
              const Divider(height: 32),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Monthly Sales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('\$1,240.50 (+12%)', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: LineChart(
                   LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 1),
                          FlSpot(1, 1.5),
                          FlSpot(2, 1.2),
                          FlSpot(3, 2),
                          FlSpot(4, 1.8),
                          FlSpot(5, 2.5),
                        ],
                        isCurved: true,
                        color: primaryColor,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: primaryColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetric(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentChats(BuildContext context) {
    final myConversations = _recentConversations.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Recent Buyer Chats', actionLabel: 'Inbox', onAction: () => context.push('/messages')),
        const SizedBox(height: 12),
        if (myConversations.isEmpty)
          _buildEmptyState('No buyer chats yet', Icons.chat_bubble_outline_rounded)
        else
          ...myConversations.map((conversation) => _buildChatTile(context, conversation)),
      ],
    );
  }

  Widget _buildChatTile(BuildContext context, ChatConversationBundle conversation) {
    final lastMessageTime = relativeTime(conversation.lastMessage?.createdAt);
    final String otherUserAvatar = ImageHelper.resolveProfileImageUrl(conversation.otherUser.avatarUrl, name: conversation.otherUser.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(otherUserAvatar),
            ),
            if (_currentUser != null && conversation.unreadCountFor(_currentUser!.id) > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(conversation.otherUser.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          lastMessageTime.isEmpty
              ? 'Re: ${conversation.product.title}'
              : 'Re: ${conversation.product.title} • $lastMessageTime',
          style: const TextStyle(fontSize: 11, color: Colors.blue),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () => context.push('/chat/${conversation.conversation.id}'),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.withValues(alpha: 0.3), size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
