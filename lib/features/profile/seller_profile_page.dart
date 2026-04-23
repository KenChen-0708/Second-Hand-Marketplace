import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../services/auth/auth_service.dart';
import '../../services/seller/seller_service.dart';
import '../../services/product/product_service.dart';
import '../../state/state.dart';
import '../../shared/utils/snackbar_helper.dart';
import '../../shared/utils/image_helper.dart';

class SellerProfilePage extends StatefulWidget {
  final String sellerId;

  const SellerProfilePage({super.key, required this.sellerId});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  UserModel? _sellerUser;
  SellerProfileModel? _sellerProfile;
  SellerStats? _sellerStats;
  List<ProductModel> _activeListings = [];
  List<ReviewModel> _reviews = [];

  final _authService = AuthService();
  final _sellerService = SellerService();
  final _productService = ProductService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _authService.fetchProfileById(widget.sellerId),
        _sellerService.fetchPublicProfile(widget.sellerId),
        _productService.fetchProducts(
          sellerId: widget.sellerId,
          status: 'active',
        ),
        _sellerService.fetchSellerReviews(widget.sellerId),
        _sellerService.getSellerStats(widget.sellerId),
      ]);

      if (mounted) {
        setState(() {
          _sellerUser = results[0] as UserModel;
          _sellerProfile = results[1] as SellerProfileModel?;
          _activeListings = results[2] as List<ProductModel>;
          _reviews = results[3] as List<ReviewModel>;
          _sellerStats = results[4] as SellerStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load seller profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging ||
        _tabController.animation?.value == _tabController.index) {
      if (mounted) setState(() {});
    }
  }

  double get _calculatedRating {
    if (_reviews.isEmpty) return 0.0;
    final sum = _reviews.fold<double>(0, (prev, r) => prev + r.rating);
    return sum / _reviews.length;
  }

  Future<void> _openSellerChat() async {
    final currentUser = context.read<UserState>().currentUser;
    if (currentUser == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text('Please log in to message this seller.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Login'),
            ),
          ],
        ),
      );
      if (shouldLogin == true && mounted) context.go('/');
      return;
    }

    if (currentUser.id == widget.sellerId) {
      SnackbarHelper.showTopMessage(context, 'This is your profile.');
      return;
    }

    try {
      if (_activeListings.isEmpty) {
        SnackbarHelper.showTopMessage(
          context,
          'No active listings available.',
        );
        return;
      }

      final product = _activeListings.first;

      final bundle = await context
          .read<ChatConversationState>()
          .getOrCreateConversationForProduct(product: product);
      if (mounted) {
        context.push('/chat/${bundle.conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _shareProfile() {
    if (_sellerUser == null) return;
    final String text =
        'Check out ${_sellerUser!.name} on CampusSell! They have ${_activeListings.length} items for sale.\n\nDownload the app to see more.';
    Share.share(text, subject: 'Seller Profile: ${_sellerUser!.name}');
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Profile Link'),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(
                    text:
                        'https://campus-marketplace.app/seller/${widget.sellerId}',
                  ),
                );
                Navigator.pop(context);
                SnackbarHelper.showTopMessage(
                  context,
                  'Link copied.',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.orange),
              title: const Text('Block Seller'),
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  'Block Seller',
                  'Are you sure you want to block this user? You will no longer see their listings.',
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.report_problem_rounded,
                color: Colors.red,
              ),
              title: const Text('Report Seller'),
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  'Report Seller',
                  'Help us keep the marketplace safe. Are you sure you want to report this user for investigation?',
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SnackbarHelper.showTopMessage(
                context,
                'Request submitted.',
              );
            },
            child: Text(
              title.split(' ').first,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _sellerUser == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Seller not found',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loadSellerData,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadSellerData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildProfileHeader(context, _sellerUser!, _sellerProfile, _sellerStats),
            ),
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
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: 'Active Listings'),
                    Tab(text: 'Reviews'),
                  ],
                ),
                Theme.of(context).colorScheme.surface,
              ),
            ),
            _tabController.index == 0
                ? _buildActiveListingsSliver(context, _activeListings)
                : _buildReviewsSliver(context, _reviews),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    UserModel seller,
    SellerProfileModel? profile,
    SellerStats? stats,
  ) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final String avatarUrl = ImageHelper.resolveProfileImageUrl(seller.avatarUrl, name: seller.name);

    // Use live calculation if profile data is missing or zero
    final double rating = stats?.averageRating ?? (profile != null && profile.averageRating > 0 
        ? profile.averageRating 
        : _calculatedRating);
    final int reviewCount = stats?.totalReviews ?? (profile != null && profile.totalReviews > 0 
        ? profile.totalReviews 
        : _reviews.length);
    final int soldCount = stats?.itemsSold ?? profile?.totalSales ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32.0),
          bottomRight: Radius.circular(32.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: cs.surfaceContainerHighest.withOpacity(
                      0.5,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.surfaceContainerHighest.withOpacity(
                          0.5,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.share_outlined, color: cs.onSurface),
                          onPressed: _shareProfile,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: cs.surfaceContainerHighest.withOpacity(
                          0.5,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: cs.onSurface,
                          ),
                          onPressed: _showMoreOptions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Hero(
              tag: 'seller_avatar_${seller.id}',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.primary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              seller.name,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (profile?.isVerified ?? false)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: cs.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Verified Student',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              
            if (seller.bio != null && seller.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  seller.bio!,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context,
                  rating.toStringAsFixed(1),
                  'Rating',
                  icon: Icons.star_rounded,
                ),
                _buildStatItem(
                  context,
                  soldCount.toString(),
                  'Sold',
                ),
                _buildStatItem(
                  context,
                  reviewCount.toString(),
                  'Reviews',
                ),
              ],
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FilledButton.icon(
                onPressed: _openSellerChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: const Text('Message Seller'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label, {
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildActiveListingsSliver(
    BuildContext context,
    List<ProductModel> products,
  ) {
    if (products.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No active listings found')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = products[index];
          return _ProductCard(product: product);
        }, childCount: products.length),
      ),
    );
  }

  Widget _buildReviewsSliver(BuildContext context, List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No reviews yet')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final review = reviews[index];
          return _ReviewTile(review: review);
        }, childCount: reviews.length),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.network(
                  product.imageUrl ?? 'https://i.pravatar.cc/300',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.reviewer?.name ?? 'Anonymous',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (review.createdAt != null)
                Text(
                  _formatDate(review.createdAt!),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                Icons.star_rounded,
                color: i < (review.rating) ? Colors.amber : cs.outlineVariant,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review.comment ?? 'No comment provided',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _TabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
