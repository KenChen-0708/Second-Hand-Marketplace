import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/local/connectivity_service.dart';
import '../../shared/utils/currency_helper.dart';
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
    Future<void> Function(CartState cartState) action,
    {String? actionKey}
  ) async {
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
            preference == 'delivery_official' ||
            preference == 'delivery_self',
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
      extra: CheckoutSessionModel(
        items: selectedItems,
      ),
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'My Cart',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selectedItems.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${selectedItems.length} selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (selectedItems.isNotEmpty)
                    TextButton(
                      onPressed: cartState.isLoading
                          ? null
                          : () => _runCartAction(
                              context,
                              (state) => state.removeMultipleFromCart(selectedItems),
                            ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
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
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final cartItem = cartState.items[index];
                              return _buildCartItem(
                                context,
                                cartItem,
                                isSelected: _selectedItemIds.contains(cartItem.id),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            if (cartState.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal ($selectedQuantity items)',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          CurrencyHelper.formatRM(selectedSubtotal),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: selectedItems.isEmpty
                            ? null
                            : () => _handleCheckoutSelected(selectedItems),
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text(
                          'Checkout Selected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
    final isQuantityActionPending = _pendingQuantityItemIds.contains(cartItem.id);
    final canIncrease =
        !cartState.isLoading &&
        !isQuantityActionPending &&
        (availableQuantity == null ||
            (availableQuantity > 0 && cartItem.quantity < availableQuantity));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: _buildSelectionControl(
              context,
              selected: isSelected,
              onTap: cartState.isLoading
                  ? null
                  : () => _toggleSelection(cartItem.id, !isSelected),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/product/${product.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ImageHelper.productImage(
                      product.imageUrl,
                      width: 96,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                product.condition,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (cartItem.variantLabel != null)
                              Container(
                                constraints: const BoxConstraints(maxWidth: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  cartItem.variantLabel!,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          CurrencyHelper.formatRM(cartItem.unitPrice),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        if (availableQuantity != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$availableQuantity available',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildQuantityButton(
                              icon: Icons.remove_rounded,
                              onPressed:
                                  cartState.isLoading || isQuantityActionPending
                                      ? null
                                      : () => _runCartAction(
                                            context,
                                            (state) =>
                                                state.decreaseQuantity(cartItem),
                                            actionKey: cartItem.id,
                                          ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${cartItem.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            _buildQuantityButton(
                              icon: Icons.add_rounded,
                              onPressed: canIncrease
                                  ? () => _runCartAction(
                                        context,
                                        (state) =>
                                            state.increaseQuantity(cartItem),
                                        actionKey: cartItem.id,
                                      )
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: cartState.isLoading
                ? null
                : () => _runCartAction(
                    context,
                    (state) => state.removeFromCart(cartItem),
                  ),
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.redAccent,
            tooltip: 'Remove',
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
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: 1.6,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: 14,
                color: colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse the marketplace and add items to your cart.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Browse Marketplace'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
