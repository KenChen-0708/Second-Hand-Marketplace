import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../../state/state.dart';
import '../../shared/utils/snackbar_helper.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<_ProductDetailData> _productDetailFuture;

  @override
  void initState() {
    super.initState();
    _productDetailFuture = _loadProductDetail();
  }

  Future<_ProductDetailData> _loadProductDetail() async {
    final productState = context.read<ProductState>();
    final product = await productState.fetchProductById(widget.productId);

    if (product == null) {
      throw Exception('Product not found.');
    }

    final sellerData = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', product.sellerId)
        .maybeSingle();

    final seller = sellerData == null
        ? null
        : UserModel.fromMap(Map<String, dynamic>.from(sellerData));

    await context.read<FavoriteState>().syncFavoriteStatus(product.id);

    return _ProductDetailData(product: product, seller: seller);
  }

  void _reloadProduct() {
    setState(() {
      _productDetailFuture = _loadProductDetail();
    });
  }

  Future<bool> _promptLoginIfNeeded(BuildContext context) async {
    final isLoggedIn = context.read<UserState>().currentUser != null;
    if (isLoggedIn) {
      return true;
    }

    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'Please log in to use your wishlist or add items to cart.',
        ),
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

    if (shouldLogin == true && context.mounted) {
      context.go('/');
    }

    return false;
  }

  void _showMessage(BuildContext context, String message) {
    SnackbarHelper.showTopMessage(context, message);
  }

  Future<void> _openSellerChat(
    BuildContext context,
    ProductModel product,
  ) async {
    if (!await _promptLoginIfNeeded(context)) {
      return;
    }

    final currentUserId = context.read<UserState>().currentUser?.id;
    if (currentUserId == product.sellerId) {
      _showMessage(context, 'This is your own listing.');
      return;
    }

    try {
      final bundle = await context
          .read<ChatConversationState>()
          .getOrCreateConversationForProduct(
            productId: product.id,
            sellerId: product.sellerId,
          );
      if (!context.mounted) {
        return;
      }
      await context.push('/chat/${bundle.conversation.id}');
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<_PurchaseSelection?> _showPurchaseOptionsSheet(
    BuildContext context,
    ProductModel product, {
    required String actionLabel,
    required IconData actionIcon,
  }) {
    return showModalBottomSheet<_PurchaseSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PurchaseOptionsSheet(
          product: product,
          actionLabel: actionLabel,
          actionIcon: actionIcon,
        );
      },
    );
  }

  Future<void> _handleAddToCart(
    BuildContext context,
    ProductModel product,
  ) async {
    if (!await _promptLoginIfNeeded(context)) {
      return;
    }

    final selection = await _showPurchaseOptionsSheet(
      context,
      product,
      actionLabel: 'Add to Cart',
      actionIcon: Icons.add_shopping_cart_rounded,
    );

    if (selection == null || !context.mounted) {
      return;
    }

    final result = await context.read<CartState>().addToCart(
      product,
      quantity: selection.quantity,
    );
    if (!context.mounted) {
      return;
    }

    final variantMessage = selection.selectedOption == null
        ? result.message
        : '${result.message} (${selection.selectedOption})';
    _showMessage(context, variantMessage);
  }

  Future<void> _handleBuyNow(BuildContext context, ProductModel product) async {
    if (!await _promptLoginIfNeeded(context)) {
      return;
    }

    final selection = await _showPurchaseOptionsSheet(
      context,
      product,
      actionLabel: 'Buy Now',
      actionIcon: Icons.flash_on_rounded,
    );

    if (selection == null || !context.mounted) {
      return;
    }

    await context.push(
      '/checkout',
      extra: CheckoutSessionModel(
        items: [
          CartModel(
            id: 'buy_now_${product.id}_${selection.selectedOption ?? 'default'}',
            product: product,
            quantity: selection.quantity,
          ),
        ],
        isBuyNow: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProductDetailData>(
      future: _productDetailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    const Icon(Icons.inventory_2_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load this product',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This product may no longer be available, or there was a connection problem.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _reloadProduct,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        }

        final detail = snapshot.data!;
        final product = detail.product;
        final seller = detail.seller;
        final sellerName = seller?.name ?? 'Seller';
        
        // Dynamic Avatar Resolution
        final sellerAvatar = ImageHelper.resolveProfileImageUrl(seller?.avatarUrl, name: seller?.name);

        final favoriteState = context.watch<FavoriteState>();
        final isFavorite = favoriteState.isFavorite(product.id);
        final isOwner =
            context.watch<UserState>().currentUser?.id == product.sellerId;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 350,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: favoriteState.isLoading
                                ? null
                                : () async {
                                    if (!await _promptLoginIfNeeded(context)) {
                                      return;
                                    }

                                    try {
                                      final message = await context
                                          .read<FavoriteState>()
                                          .toggleFavorite(product.id);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      _showMessage(context, message);
                                    } catch (e) {
                                      if (!context.mounted) {
                                        return;
                                      }
                                      _showMessage(
                                        context,
                                        e.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
                                    }
                                  },
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite
                                  ? Colors.redAccent
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Hero(
                        tag: 'product_image_${product.id}',
                        child: ImageHelper.productImage(
                          product.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    if (product.updatedAt != null &&
                                        product.createdAt != null &&
                                        product.updatedAt!.isAfter(
                                          product.createdAt!.add(
                                            const Duration(seconds: 10),
                                          ),
                                        ))
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'EDITED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[600],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  product.condition,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.description,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Sold By',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    context.push('/seller/${product.sellerId}'),
                                child: Hero(
                                  tag: 'seller_avatar_${product.sellerId}',
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage(sellerAvatar),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => context.push(
                                    '/seller/${product.sellerId}',
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sellerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        seller?.bio?.isNotEmpty == true
                                            ? seller!.bio!
                                            : 'Campus seller',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                ),
                                color: isOwner
                                    ? Theme.of(context).disabledColor
                                    : Theme.of(context).colorScheme.primary,
                                tooltip: 'Chat with seller',
                                onPressed: isOwner
                                    ? null
                                    : () => _openSellerChat(context, product),
                              ),
                            ],
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Consumer2<UserState, ProductState>(
                  builder: (context, userState, productState, child) {
                    final isOwner =
                        userState.currentUser?.id == product.sellerId;

                    if (isOwner) {
                      return Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, -4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Remove Listing?'),
                                      content: const Text(
                                        'Are you sure you want to remove this listing? This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && context.mounted) {
                                    try {
                                      await productState.deleteProduct(
                                        product.id,
                                      );
                                      if (context.mounted) {
                                        _showMessage(
                                          context,
                                          'Listing removed successfully',
                                        );
                                        context.pop(); // Go back after deletion
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        SnackbarHelper.showError(
                                          context,
                                          'Something went wrong. Please try again.',
                                        );
                                      }
                                    }
                                  }
                                },
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  await context.push(
                                    '/edit-product',
                                    extra: product,
                                  );
                                  // The details will automatically update because of ProductState and FutureBuilder reload
                                  _reloadProduct();
                                },
                                child: const Text(
                                  'Edit Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                await _handleAddToCart(context, product);
                              },
                              icon: const Icon(Icons.add_shopping_cart_rounded),
                              label: const Text(
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => _handleBuyNow(context, product),
                              icon: const Icon(Icons.flash_on_rounded),
                              label: const Text(
                                'Buy Now',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductDetailData {
  const _ProductDetailData({required this.product, required this.seller});

  final ProductModel product;
  final UserModel? seller;
}

class _PurchaseSelection {
  const _PurchaseSelection({required this.quantity, this.selectedOption});

  final int quantity;
  final String? selectedOption;
}

class _PurchaseOptionsSheet extends StatefulWidget {
  const _PurchaseOptionsSheet({
    required this.product,
    required this.actionLabel,
    required this.actionIcon,
  });

  final ProductModel product;
  final String actionLabel;
  final IconData actionIcon;

  @override
  State<_PurchaseOptionsSheet> createState() => _PurchaseOptionsSheetState();
}

class _PurchaseOptionsSheetState extends State<_PurchaseOptionsSheet> {
  late final List<String> _options;
  late String _selectedOption;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _options = _buildOptions(widget.product);
    _selectedOption = _options.first;
  }

  List<String> _buildOptions(ProductModel product) {
    final options = <String>[
      if (product.condition.isNotEmpty) product.condition,
      if (product.tradePreference.isNotEmpty)
        _formatTradePreference(product.tradePreference),
      if (product.openToOffers) 'Negotiable',
    ].toSet().toList();

    if (options.isEmpty) {
      return const ['Standard'];
    }

    return options;
  }

  String _formatTradePreference(String tradePreference) {
    return tradePreference
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final product = widget.product;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ImageHelper.productImage(
                        product.imageUrl,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Variation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _options.map((option) {
                    final isSelected = option == _selectedOption;
                    return ChoiceChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedOption = option),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Quantity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _QuantityButton(
                      icon: Icons.remove_rounded,
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity -= 1)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add_rounded,
                      onPressed: () => setState(() => _quantity += 1),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _PurchaseSelection(
                        quantity: _quantity,
                        selectedOption: _selectedOption,
                      ),
                    ),
                    icon: Icon(widget.actionIcon),
                    label: Text(widget.actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
