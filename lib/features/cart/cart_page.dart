import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/local/connectivity_service.dart';
import '../../shared/utils/currency_helper.dart';
import '../../shared/widgets/purchase_selection_sheet.dart';
import '../../state/state.dart';
import '../../shared/utils/image_helper.dart';
import '../../shared/utils/snackbar_helper.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedItemIds = <String>{};
  final Set<String> _pendingQuantityItemIds = <String>{};

  Future<void> _runCartAction(
    BuildContext context,
    Future<void> Function(CartState cartState) action, {
    String? actionKey,
  }) async {
    if (actionKey != null) {
      if (_pendingQuantityItemIds.contains(actionKey)) {
        return;
      }
      setState(() {
        _pendingQuantityItemIds.add(actionKey);
      });
    }

    final cartState = context.read<CartState>();
    try {
      await action(cartState);
    } finally {
      if (actionKey != null && mounted) {
        setState(() {
          _pendingQuantityItemIds.remove(actionKey);
        });
      }
    }

    if (!context.mounted || cartState.error == null) {
      return;
    }

    SnackbarHelper.showTopMessage(context, cartState.error!);
  }

  void _syncSelection(List<CartModel> items) {
    final validIds = items.map((item) => item.id).toSet();
    _selectedItemIds.removeWhere((id) => !validIds.contains(id));
  }

  void _toggleSelection(String itemId, bool selected) {
    setState(() {
      if (selected) {
        _selectedItemIds.add(itemId);
      } else {
        _selectedItemIds.remove(itemId);
      }
    });
  }

  void _toggleSelectAll(List<CartModel> items, bool selected) {
    setState(() {
      if (selected) {
        _selectedItemIds
          ..clear()
          ..addAll(items.map((item) => item.id));
      } else {
        _selectedItemIds.clear();
      }
    });
  }

  bool _sharesCommonHandoverOption(List<CartModel> items) {
    if (items.isEmpty) {
      return false;
    }

    Set<String>? commonOptions;
    for (final item in items) {
      final itemOptions = <String>{};
      if (item.product.tradePreference.contains('face_to_face')) {
        itemOptions.add('meet_up');
      }
      if (item.product.tradePreference.any(
        (preference) =>
            preference == 'delivery_official' || preference == 'delivery_self',
      )) {
        itemOptions.add('delivery');
      }

      commonOptions = commonOptions == null
          ? itemOptions
          : commonOptions.intersection(itemOptions);
    }

    return commonOptions != null && commonOptions.isNotEmpty;
  }

  Future<void> _handleCheckoutSelected(List<CartModel> selectedItems) async {
    if (selectedItems.isEmpty) {
      SnackbarHelper.showInfo(context, 'Select at least one item.');
      return;
    }

    if (!_sharesCommonHandoverOption(selectedItems)) {
      SnackbarHelper.showWarning(
        context,
        'These items need separate checkout.',
      );
      return;
    }

    if (!await ConnectivityService.instance.isOnline()) {
      if (!mounted) {
        return;
      }
      SnackbarHelper.showInfo(
        context,
        'No internet connection. Please try again.',
      );
      return;
    }

    context.push(
      '/checkout',
      extra: CheckoutSessionModel(items: selectedItems),
    );
  }

  Future<void> _editCartItemSelection(
    BuildContext context,
    CartModel cartItem,
  ) async {
    final selection = await showModalBottomSheet<PurchaseSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PurchaseSelectionSheet(
        product: cartItem.product,
        actionLabel: 'Update Cart',
        actionIcon: Icons.tune_rounded,
        initialVariant: cartItem.selectedVariant,
        initialQuantity: cartItem.quantity,
      ),
    );

    if (selection == null || !context.mounted) {
      return;
    }

    if (_pendingQuantityItemIds.contains(cartItem.id)) {
      return;
    }

    final wasSelected = _selectedItemIds.contains(cartItem.id);
    setState(() {
      _pendingQuantityItemIds.add(cartItem.id);
    });

    final cartState = context.read<CartState>();
    try {
      final result = await cartState.replaceCartItemSelection(
        cartItem,
        selectedVariant: selection.selectedVariant,
        quantity: selection.quantity,
      );

      if (!mounted) {
        return;
      }

      if (result.success && wasSelected) {
        setState(() {
          _selectedItemIds.remove(cartItem.id);
          if (result.item != null) {
            _selectedItemIds.add(result.item!.id);
          }
        });
      }

      if (!result.success) {
        SnackbarHelper.showTopMessage(context, result.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingQuantityItemIds.remove(cartItem.id);
        });
      }
    }
  }

  Future<void> _updateCartItemQuantity(
    BuildContext context,
    CartModel cartItem,
    int quantity,
  ) async {
    await _runCartAction(
      context,
      (state) => state.updateQuantity(cartItem, quantity),
      actionKey: cartItem.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cartState = context.watch<CartState>();
    _syncSelection(cartState.items);
    final selectedItems = cartState.items
        .where((item) => _selectedItemIds.contains(item.id))
        .toList();
    final selectedQuantity = selectedItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final selectedSubtotal = selectedItems.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    final isAllSelected =
        cartState.items.isNotEmpty &&
        _selectedItemIds.length == cartState.items.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Back Button - Minimal design
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 20,
                      color: colorScheme.onSurface,
                    ),
                    onPressed: () => context.pop(),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'My Cart',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  // Edit/Clear All button
                  if (selectedItems.isNotEmpty)
                    TextButton.icon(
                      onPressed: cartState.isLoading
                          ? null
                          : () => _runCartAction(
                              context,
                              (state) =>
                                  state.removeMultipleFromCart(selectedItems),
                            ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: cartState.isLoading && cartState.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : cartState.isEmpty
                  ? _buildEmptyCart(context)
                  : Column(
                      children: [
                        if (selectedItems.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Row(
                              children: [
                                _buildSelectionControl(
                                  context,
                                  selected: isAllSelected,
                                  onTap: cartState.isLoading
                                      ? null
                                      : () => _toggleSelectAll(
                                          cartState.items,
                                          !isAllSelected,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Select all',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: cartState.items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final cartItem = cartState.items[index];
                              return _buildCartItem(
                                context,
                                cartItem,
                                isSelected: _selectedItemIds.contains(
                                  cartItem.id,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            if (cartState.isNotEmpty)
              // Modern Checkout Summary
              Container(
                padding: const EdgeInsets.only(
                  top: 14,
                  left: 20,
                  right: 20,
                  bottom: 18,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Items',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$selectedQuantity ${selectedQuantity == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                CurrencyHelper.formatRM(selectedSubtotal),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Checkout button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: selectedItems.isEmpty
                            ? null
                            : () => _handleCheckoutSelected(selectedItems),
                        style: FilledButton.styleFrom(
                          backgroundColor: selectedItems.isEmpty
                              ? colorScheme.onSurface.withOpacity(0.12)
                              : colorScheme.primary,
                          foregroundColor: selectedItems.isEmpty
                              ? colorScheme.onSurface.withOpacity(0.38)
                              : colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: selectedItems.isEmpty
                                  ? colorScheme.onSurface.withOpacity(0.38)
                                  : colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              selectedItems.isEmpty
                                  ? 'Select items to checkout'
                                  : 'Proceed to Checkout',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
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
        ),
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartModel cartItem, {
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final product = cartItem.product;
    final cartState = context.read<CartState>();
    final availableQuantity =
        cartItem.selectedVariant?.availableQuantity ?? product.stockQuantity;
    final isQuantityActionPending = _pendingQuantityItemIds.contains(
      cartItem.id,
    );
    final variantText = cartItem.selectedVariant?.attributeSummary ?? 'Generic';
    final canIncrease =
        !cartState.isLoading &&
        !isQuantityActionPending &&
        (availableQuantity == null ||
            (availableQuantity > 0 && cartItem.quantity < availableQuantity));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selection checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildSelectionControl(
                    context,
                    selected: isSelected,
                    onTap: cartState.isLoading
                        ? null
                        : () => _toggleSelection(cartItem.id, !isSelected),
                  ),
                ),
                const SizedBox(width: 10),
                // Product image
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => context.push('/product/${product.id}'),
                      child: ImageHelper.productImage(
                        product.imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product title
                      InkWell(
                        onTap: () => context.push('/product/${product.id}'),
                        child: Text(
                          product.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Variant info
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                variantText,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (product.variations.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap:
                                    cartState.isLoading ||
                                        isQuantityActionPending
                                    ? null
                                    : () => _editCartItemSelection(
                                        context,
                                        cartItem,
                                      ),
                                child: Text(
                                  'Change',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Price and total
                      Row(
                        children: [
                          Text(
                            CurrencyHelper.formatRM(cartItem.unitPrice),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
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
          // Divider
          Container(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.1),
          ),
          // Quantity controls and delete
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Delete button
                IconButton(
                  onPressed: cartState.isLoading
                      ? null
                      : () => _runCartAction(
                          context,
                          (state) => state.removeFromCart(cartItem),
                        ),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                  ),
                ),
                const Spacer(),
                // Quantity label
                Text(
                  'Quantity',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Decrease button
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          onPressed:
                              cartState.isLoading || isQuantityActionPending
                              ? null
                              : () => _runCartAction(
                                  context,
                                  (state) => state.decreaseQuantity(cartItem),
                                  actionKey: cartItem.id,
                                ),
                          icon: Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color:
                                cartState.isLoading || isQuantityActionPending
                                ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                : colorScheme.onSurface,
                          ),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Quantity display
                      Container(
                        width: 64,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            vertical: BorderSide(
                              color: colorScheme.outlineVariant.withOpacity(
                                0.2,
                              ),
                            ),
                          ),
                        ),
                        child: _CartQuantityField(
                          value: cartItem.quantity,
                          enabled:
                              !cartState.isLoading && !isQuantityActionPending,
                          maxQuantity: availableQuantity,
                          onCommitted: (value) =>
                              _updateCartItemQuantity(context, cartItem, value),
                        ),
                      ),
                      // Increase button
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          onPressed: canIncrease
                              ? () => _runCartAction(
                                  context,
                                  (state) => state.increaseQuantity(cartItem),
                                  actionKey: cartItem.id,
                                )
                              : null,
                          icon: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: canIncrease
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 30,
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildSelectionControl(
    BuildContext context, {
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: 1.6,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 14, color: colorScheme.onPrimary)
            : null,
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated illustration container
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer circle
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(
                        0.6,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Cart icon
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 70,
                    color: colorScheme.primary.withOpacity(0.8),
                  ),
                  // Plus icon indicator
                  Positioned(
                    bottom: 30,
                    right: 30,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        size: 24,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Title
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              'Looks like you haven\'t added any items to your cart yet. Start shopping to fill it up!',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Browse Marketplace',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartQuantityField extends StatefulWidget {
  const _CartQuantityField({
    required this.value,
    required this.enabled,
    required this.onCommitted,
    this.maxQuantity,
  });

  final int value;
  final bool enabled;
  final int? maxQuantity;
  final ValueChanged<int> onCommitted;

  @override
  State<_CartQuantityField> createState() => _CartQuantityFieldState();
}

class _CartQuantityFieldState extends State<_CartQuantityField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CartQuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.value = TextEditingValue(
        text: '${widget.value}',
        selection: TextSelection.collapsed(offset: '${widget.value}'.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final parsedValue = int.tryParse(_controller.text.trim()) ?? widget.value;
    var nextValue = parsedValue < 1 ? 1 : parsedValue;
    final maxQuantity = widget.maxQuantity;
    if (maxQuantity != null && maxQuantity > 0 && nextValue > maxQuantity) {
      nextValue = maxQuantity;
    }

    _controller.value = TextEditingValue(
      text: '$nextValue',
      selection: TextSelection.collapsed(offset: '$nextValue'.length),
    );

    if (nextValue != widget.value) {
      widget.onCommitted(nextValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
