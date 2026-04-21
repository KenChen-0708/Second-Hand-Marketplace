import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/auth/auth_service.dart';
import '../../services/chat/chat_service.dart';
import '../../services/seller/seller_service.dart';
import '../../shared/utils/currency_helper.dart';
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
  String? _error;
  SellerStats? _stats;
  UserModel? _currentUser;
  SellerProfileModel? _sellerProfile;
  List<SellerNeedAction> _needsAction = const [];
  Map<String, List<OrderModel>> _ordersSummary = const {};
  List<ProductModel> _listings = const [];
  List<ChatConversationBundle> _recentConversations = const [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _authService.supabase.auth.currentUser?.email;
      if (email == null) {
        throw Exception('Please sign in to view your seller dashboard.');
      }

      final user = await _authService.fetchProfileByEmail(email);
      final userId = user.id;
      final results = await Future.wait<Object?>([
        _sellerService.getSellerStats(userId),
        _sellerService.fetchPublicProfile(userId),
        _sellerService.getNeedsAction(userId),
        _sellerService.getOrdersSummary(userId),
        _sellerService.getListings(userId),
        _chatService.fetchUserConversations(userId: userId),
      ]);

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _stats = results[0] as SellerStats;
        _sellerProfile = results[1] as SellerProfileModel?;
        _needsAction = results[2] as List<SellerNeedAction>;
        _ordersSummary = results[3] as Map<String, List<OrderModel>>;
        _listings = (results[4] as List<ProductModel>)
            .where((product) => product.status.toLowerCase() != 'draft')
            .toList();
        _recentConversations = results[5] as List<ChatConversationBundle>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState(context)
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    sliver: SliverList.list(
                      children: [
                        _buildSummaryCards(context),
                        const SizedBox(height: 24),
                        if (_needsAction.isNotEmpty) ...[
                          _buildSectionTitle(
                            'Needs Action',
                            actionLabel: '${_needsAction.length}',
                            attention: true,
                          ),
                          const SizedBox(height: 12),
                          ..._needsAction.take(4).map(_buildActionCard),
                          const SizedBox(height: 24),
                        ],
                        _buildUpcomingHandovers(context),
                        const SizedBox(height: 24),
                        _buildRecentOrders(context),
                        const SizedBox(height: 24),
                        _buildListingsOverview(context),
                        const SizedBox(height: 24),
                        _buildPerformance(context),
                        const SizedBox(height: 24),
                        _buildRecentChats(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sell'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Listing'),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = _currentUser;
    final profile = _sellerProfile;
    final joined = user?.createdAt == null
        ? null
        : DateFormat('MMM yyyy').format(user!.createdAt!);
    final avatarUrl = ImageHelper.resolveProfileImageUrl(
      user?.avatarUrl,
      name: user?.name,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 58, 24, 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seller Dashboard',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user == null ? 'Welcome back' : 'Hi, ${user.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(
                      profile?.isVerified == true
                          ? 'Verified Seller'
                          : 'Seller',
                      profile?.isVerified == true
                          ? Icons.verified_user_rounded
                          : Icons.storefront_rounded,
                      profile?.isVerified == true
                          ? const Color(0xFF10B981)
                          : colors.primary,
                    ),
                    if (joined != null)
                      _statusChip(
                        'Joined $joined',
                        Icons.calendar_month_rounded,
                        Colors.blueGrey,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(radius: 31, backgroundImage: NetworkImage(avatarUrl)),
        ],
      ),
    );
  }

  Widget _statusChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final stats = _stats;
    final unreadChats = _currentUser == null
        ? 0
        : _recentConversations.fold<int>(
            0,
            (sum, bundle) => sum + bundle.unreadCountFor(_currentUser!.id),
          );
    final awaiting = _awaitingActionOrders.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 620;
        final cards = [
          _DashboardMetric(
            'Active Listings',
            '${stats?.activeListings ?? _activeListings.length}',
            Icons.inventory_2_outlined,
            Colors.blue,
          ),
          _DashboardMetric(
            'Items Sold',
            '${stats?.itemsSold ?? 0}',
            Icons.shopping_bag_outlined,
            const Color(0xFF10B981),
          ),
          _DashboardMetric(
            'Awaiting Action',
            '$awaiting',
            Icons.notification_important_outlined,
            Colors.orange,
            highlight: awaiting > 0,
          ),
          _DashboardMetric(
            'Total Earnings',
            CurrencyHelper.formatRM(stats?.totalEarnings ?? 0),
            Icons.account_balance_wallet_outlined,
            Colors.purple,
          ),
          _DashboardMetric(
            'Unread Chats',
            '$unreadChats',
            Icons.chat_bubble_outline_rounded,
            Colors.teal,
            highlight: unreadChats > 0,
          ),
        ];

        if (isWide) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map(
                  (metric) => SizedBox(
                    width: (constraints.maxWidth - 24) / 3,
                    child: _metricCard(metric),
                  ),
                )
                .toList(),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (metric) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: _metricCard(metric),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _metricCard(_DashboardMetric metric) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 142),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: metric.highlight
              ? metric.color.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: metric.color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
    bool attention = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (attention) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }

  Widget _buildActionCard(SellerNeedAction action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAction(action),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        action.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    action.ctaLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingHandovers(BuildContext context) {
    final handovers =
        [...(_ordersSummary['ready_for_handover'] ?? const <OrderModel>[])]
          ..sort((a, b) {
            final aTime = a.handoverDate ?? DateTime(9999);
            final bTime = b.handoverDate ?? DateTime(9999);
            return aTime.compareTo(bTime);
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Upcoming Handovers'),
        const SizedBox(height: 12),
        if (handovers.isEmpty)
          _emptyPanel('No scheduled handovers', Icons.event_available_outlined)
        else
          ...handovers.take(3).map(_handoverCard),
      ],
    );
  }

  Widget _handoverCard(OrderModel order) {
    final date = order.handoverDate == null
        ? 'Schedule needed'
        : DateFormat('MMM dd, h:mm a').format(order.handoverDate!);
    final productTitle = _orderTitle(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Buyer: ${order.buyer?.name ?? 'Unknown'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 96,
                    child: Text(
                      order.handoverLocation ?? 'No location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChatForOrder(order),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Chat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.push('/profile/order-status', extra: order);
                    if (mounted) {
                      await _loadDashboardData();
                    }
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context) {
    final tabs = [
      (
        'Pending',
        _ordersSummary['awaiting_confirmation'] ?? const <OrderModel>[],
      ),
      (
        'Handover',
        _ordersSummary['ready_for_handover'] ?? const <OrderModel>[],
      ),
      ('Completed', _ordersSummary['completed'] ?? const <OrderModel>[]),
      ('Closed', _ordersSummary['cancelled'] ?? const <OrderModel>[]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Recent Orders',
          actionLabel: 'View All',
          onAction: () => context.push('/profile/orders'),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
          ),
          child: DefaultTabController(
            length: tabs.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  tabs: tabs
                      .map((tab) => Tab(text: '${tab.$1} (${tab.$2.length})'))
                      .toList(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 194,
                  child: TabBarView(
                    children: tabs.map((tab) => _orderList(tab.$2)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _orderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return _emptyPanel('No orders here', Icons.shopping_basket_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: orders.length > 3 ? 3 : orders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final order = orders[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 2,
          ),
          title: Text(
            _orderTitle(order),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          subtitle: Text(
            '${order.buyer?.name ?? 'Buyer'} - ${_statusLabel(order.status)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(
            CurrencyHelper.formatRM(order.totalPrice),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF10B981),
              fontSize: 12,
            ),
          ),
          onTap: () async {
            await context.push('/profile/order-status', extra: order);
            if (mounted) {
              await _loadDashboardData();
            }
          },
        );
      },
    );
  }

  Widget _buildListingsOverview(BuildContext context) {
    final active = _activeListings;
    final sold = _listings
        .where((product) => product.status.toLowerCase() == 'sold')
        .toList();
    final lowStock = active
        .where((product) => (product.stockQuantity ?? 1) <= 1)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'My Listings',
          actionLabel: 'Manage All',
          onAction: () async {
            await context.push('/profile/listings');
            if (mounted) {
              await _loadDashboardData();
            }
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _listingCountCard('Active', active.length, Colors.blue),
              _listingCountCard('Sold', sold.length, const Color(0xFF10B981)),
              _listingCountCard('Low Stock', lowStock.length, Colors.redAccent),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (active.isEmpty)
          _emptyPanel('No active listings yet', Icons.inventory_2_outlined)
        else
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: active.length > 8 ? 8 : active.length,
              itemBuilder: (context, index) => _productCard(active[index]),
            ),
          ),
      ],
    );
  }

  Widget _listingCountCard(String label, int count, Color color) {
    return Container(
      width: 118,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _productCard(ProductModel product) {
    return InkWell(
      onTap: () async {
        await context.push('/product/${product.id}');
        if (mounted) {
          await _loadDashboardData();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 138,
        margin: const EdgeInsets.only(right: 12),
        decoration: _panelDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ImageHelper.productImage(
                product.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    CurrencyHelper.formatRM(product.price),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformance(BuildContext context) {
    final stats = _stats;
    final completedOrders = _ordersSummary['completed'] ?? const <OrderModel>[];
    final monthlyEarnings = _monthlyEarnings(completedOrders);
    final maxY = monthlyEarnings.fold<double>(
      0,
      (max, item) => item > max ? item : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Earnings & Performance'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _panelDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _performanceMetric(
                      'Average Rating',
                      (stats?.averageRating ??
                              _sellerProfile?.averageRating ??
                              0)
                          .toStringAsFixed(1),
                      Icons.star_rounded,
                      Colors.amber[700]!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _performanceMetric(
                      'Reviews',
                      '${stats?.totalReviews ?? _sellerProfile?.totalReviews ?? 0}',
                      Icons.rate_review_outlined,
                      Colors.indigo,
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Last 6 Months',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    CurrencyHelper.formatRM(
                      monthlyEarnings.fold<double>(
                        0,
                        (sum, value) => sum + value,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY <= 0 ? 10 : maxY * 1.2,
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          monthlyEarnings.length,
                          (index) =>
                              FlSpot(index.toDouble(), monthlyEarnings[index]),
                        ),
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
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

  Widget _performanceMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChats(BuildContext context) {
    final conversations = _recentConversations
        .where((bundle) => bundle.conversation.sellerId == _currentUser?.id)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Recent Buyer Chats',
          actionLabel: 'Inbox',
          onAction: () => context.push('/messages'),
        ),
        const SizedBox(height: 12),
        if (conversations.isEmpty)
          _emptyPanel('No buyer chats yet', Icons.chat_bubble_outline_rounded)
        else
          ...conversations.map(_chatTile),
      ],
    );
  }

  Widget _chatTile(ChatConversationBundle bundle) {
    final currentUserId = _currentUser?.id ?? '';
    final unread = bundle.unreadCountFor(currentUserId);
    final avatar = ImageHelper.resolveProfileImageUrl(
      bundle.otherUser.avatarUrl,
      name: bundle.otherUser.name,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _panelDecoration(),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(avatar)),
            if (unread > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          bundle.otherUser.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Re: ${bundle.product.title}${_relativeTime(bundle.lastMessage?.createdAt).isEmpty ? '' : ' - ${_relativeTime(bundle.lastMessage?.createdAt)}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/chat/${bundle.conversation.id}'),
      ),
    );
  }

  Widget _emptyPanel(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 34, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  List<ProductModel> get _activeListings => _listings
      .where((product) => product.status.toLowerCase() == 'active')
      .toList();

  List<OrderModel> get _awaitingActionOrders {
    final awaiting = <OrderModel>[
      ...(_ordersSummary['awaiting_confirmation'] ?? const <OrderModel>[]),
      ...(_ordersSummary['ready_for_handover'] ?? const <OrderModel>[]),
    ];
    return awaiting;
  }

  List<double> _monthlyEarnings(List<OrderModel> completedOrders) {
    final now = DateTime.now();
    final months = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - (5 - index));
      return DateTime(month.year, month.month);
    });

    return months.map((month) {
      return completedOrders
          .where((order) {
            final date = order.updatedAt ?? order.createdAt;
            return date != null &&
                date.year == month.year &&
                date.month == month.month;
          })
          .fold<double>(0, (sum, order) => sum + order.totalPrice);
    }).toList();
  }

  String _orderTitle(OrderModel order) {
    if (order.orderItems.isEmpty) return 'Order #${order.orderNumber}';
    final first = order.orderItems.first.product?.title ?? 'Product';
    final remaining = order.orderItems.length - 1;
    return remaining > 0 ? '$first + $remaining more' : first;
  }

  String _statusLabel(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(date);
  }

  Future<void> _openAction(SellerNeedAction action) async {
    final order = _findOrder(action.relatedId);
    if (order != null) {
      await context.push('/profile/order-status', extra: order);
      if (mounted) {
        await _loadDashboardData();
      }
      return;
    }
    await context.push('/profile/orders');
    if (mounted) {
      await _loadDashboardData();
    }
  }

  OrderModel? _findOrder(String? orderId) {
    if (orderId == null) return null;
    for (final orders in _ordersSummary.values) {
      for (final order in orders) {
        if (order.id == orderId) return order;
      }
    }
    return null;
  }

  Future<void> _openChatForOrder(OrderModel order) async {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null || order.orderItems.isEmpty) return;

    try {
      final bundle = await _chatService.getOrCreateConversation(
        productId: order.orderItems.first.productId,
        buyerId: order.buyerId,
        sellerId: currentUserId,
        currentUserId: currentUserId,
      );

      if (mounted) {
        context.push('/chat/${bundle.conversation.id}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open chat: $e')));
    }
  }
}

class _DashboardMetric {
  const _DashboardMetric(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;
}
