import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';

// Mock Reviews
class Review {
  final String buyerName;
  final int rating; // 1-5
  final String comment;
  final DateTime date;
  final String? productName;

  Review({
    required this.buyerName,
    required this.rating,
    required this.comment,
    required this.date,
    this.productName,
  });
}

final List<Review> mockReviews = [
  Review(
    buyerName: 'John D.',
    rating: 5,
    comment:
        'Great seller! Fast response and textbook was exactly as described.',
    date: DateTime.now().subtract(const Duration(days: 2)),
    productName: 'Linear Algebra Textbook',
  ),
  Review(
    buyerName: 'Emily W.',
    rating: 4,
    comment:
        'Smooth transaction, but took a little while to respond to the first message.',
    date: DateTime.now().subtract(const Duration(days: 15)),
    productName: 'Mechanical Keyboard',
  ),
  Review(
    buyerName: 'Anonymous',
    rating: 5,
    comment: 'Perfect condition. Thanks!',
    date: DateTime.now().subtract(const Duration(days: 45)),
  ),
];

class SellerProfilePage extends StatefulWidget {
  final String sellerId;

  const SellerProfilePage({super.key, required this.sellerId});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging ||
        _tabController.animation?.value == _tabController.index) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Find seller from mock data
    final seller = [
      mockSeller1,
      mockSeller2,
      mockUser,
    ].firstWhere((u) => u.id == widget.sellerId, orElse: () => mockSeller1);

    // Find active listings
    final activeListings = mockProducts
        .where((p) => p.seller.id == seller.id)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildProfileHeader(context, seller)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3.0,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Active Listings'),
                  Tab(text: 'Reviews'),
                ],
              ),
              Theme.of(context).colorScheme.surface,
            ),
          ),
          _tabController.index == 0
              ? _buildActiveListingsSliver(context, activeListings)
              : _buildReviewsSliver(context),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User seller) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24.0),
          bottomRight: Radius.circular(24.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header Action Row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.more_horiz_rounded, color: cs.onSurface),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Profile Picture
            Hero(
              tag: 'seller_avatar_${seller.id}',
              child: CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(seller.avatarUrl),
              ),
            ),
            const SizedBox(height: 16),
            // Name & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  seller.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.verified_rounded, color: cs.primary, size: 24),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Verified Student',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            // Trust metrics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMetricItem(
                    context,
                    title: '4.8/5.0',
                    subtitle: 'Rating',
                    icon: Icons.star_rounded,
                  ),
                  Container(width: 1, height: 40, color: cs.outlineVariant),
                  _buildMetricItem(
                    context,
                    title:
                        '${activeListingsCount(seller.id) + 10}', // Mock dynamic looking total sales
                    subtitle: 'Items Sold',
                  ),
                  Container(width: 1, height: 40, color: cs.outlineVariant),
                  _buildMetricItem(context, title: '2024', subtitle: 'Joined'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int activeListingsCount(String sellerId) {
    return mockProducts.where((p) => p.seller.id == sellerId).length;
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActiveListingsSliver(
    BuildContext context,
    List<Product> activeListings,
  ) {
    if (activeListings.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No active listings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = activeListings[index];
          return GestureDetector(
            onTap: () {
              context.push('/home/product/${product.id}');
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24.0),
                      ),
                      child: Hero(
                        tag: 'product_image_${product.id}_profile',
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                product.condition,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: activeListings.length),
      ),
    );
  }

  Widget _buildReviewsSliver(BuildContext context) {
    if (mockReviews.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text("No reviews yet.")),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final review = mockReviews[index];
          final cs = Theme.of(context).colorScheme;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        review.buyerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${review.date.day}/${review.date.month}/${review.date.year}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    review.comment,
                    style: TextStyle(color: cs.onSurface, height: 1.4),
                  ),
                  if (review.productName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            review.productName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }, childCount: mockReviews.length),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _TabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height + 8; // some padding
  @override
  double get maxExtent => tabBar.preferredSize.height + 8;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
