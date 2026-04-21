import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../utils/image_helper.dart';

class PurchaseSelection {
  const PurchaseSelection({
    required this.quantity,
    this.selectedOption,
    this.selectedVariant,
  });

  final int quantity;
  final String? selectedOption;
  final ProductVariationModel? selectedVariant;
}

class PurchaseSelectionSheet extends StatefulWidget {
  const PurchaseSelectionSheet({
    super.key,
    required this.product,
    required this.actionLabel,
    required this.actionIcon,
    this.initialVariant,
    this.initialQuantity = 1,
  });

  final ProductModel product;
  final String actionLabel;
  final IconData actionIcon;
  final ProductVariationModel? initialVariant;
  final int initialQuantity;

  @override
  State<PurchaseSelectionSheet> createState() => _PurchaseSelectionSheetState();
}

class _PurchaseSelectionSheetState extends State<PurchaseSelectionSheet> {
  ProductVariationModel? _selectedVariant;
  final Map<String, String> _selectedAttributes = {};
  late final TextEditingController _quantityController;
  late final FocusNode _quantityFocusNode;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity < 1 ? 1 : widget.initialQuantity;
    _quantityController = TextEditingController(text: '$_quantity');
    _quantityFocusNode = FocusNode()..addListener(_handleQuantityFocusChange);

    if (widget.product.variations.isNotEmpty) {
      _selectedVariant = _resolveInitialVariant();
      if (_selectedVariant != null) {
        _selectedAttributes
          ..clear()
          ..addAll(_selectedVariant!.normalizedAttributes);
      }
    }

    _applyQuantityBounds();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _quantityFocusNode
      ..removeListener(_handleQuantityFocusChange)
      ..dispose();
    super.dispose();
  }

  ProductVariationModel? _resolveInitialVariant() {
    final initialVariant = widget.initialVariant;
    if (initialVariant != null) {
      for (final variation in widget.product.variations) {
        if (variation.id == initialVariant.id) {
          return variation;
        }
      }
    }

    return widget.product.variations.firstWhere(
      (variation) => variation.availableQuantity > 0,
      orElse: () => widget.product.variations.first,
    );
  }

  int? get _stockLimit {
    if (_selectedVariant != null) {
      return _selectedVariant!.availableQuantity;
    }
    return widget.product.stockQuantity;
  }

  List<String> get _attributeNames {
    final names = <String>[];
    for (final variation in widget.product.variations) {
      for (final name in variation.normalizedAttributes.keys) {
        if (!names.contains(name)) {
          names.add(name);
        }
      }
    }
    return names;
  }

  List<String> _allValuesForAttribute(String attributeName) {
    final values = <String>[];
    for (final variation in widget.product.variations) {
      final value = variation.normalizedAttributes[attributeName];
      if (value != null && value.isNotEmpty && !values.contains(value)) {
        values.add(value);
      }
    }
    return values;
  }

  bool _matchesOtherSelections(
    ProductVariationModel variation,
    String activeAttribute,
  ) {
    final attributes = variation.normalizedAttributes;
    for (final entry in _selectedAttributes.entries) {
      if (entry.key == activeAttribute) {
        continue;
      }
      if (attributes[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  ProductVariationModel? _firstMatchingVariantFor(
    String attributeName,
    String attributeValue,
  ) {
    final matches = widget.product.variations.where((variation) {
      final attributes = variation.normalizedAttributes;
      return attributes[attributeName] == attributeValue &&
          _matchesOtherSelections(variation, attributeName);
    }).toList();

    if (matches.isEmpty) {
      return null;
    }

    return matches.firstWhere(
      (variation) => variation.availableQuantity > 0,
      orElse: () => matches.first,
    );
  }

  void _selectAttributeValue(String attributeName, String attributeValue) {
    final matchedVariant = _firstMatchingVariantFor(attributeName, attributeValue);
    if (matchedVariant == null) {
      return;
    }

    setState(() {
      _selectedVariant = matchedVariant;
      _selectedAttributes
        ..clear()
        ..addAll(matchedVariant.normalizedAttributes);
      _applyQuantityBounds();
    });
  }

  void _handleQuantityFocusChange() {
    if (!_quantityFocusNode.hasFocus) {
      _commitQuantityInput();
    }
  }

  void _applyQuantityBounds() {
    final stockLimit = _stockLimit;
    if (stockLimit != null) {
      if (stockLimit <= 0) {
        _quantity = 1;
      } else if (_quantity > stockLimit) {
        _quantity = stockLimit;
      }
    }

    if (_quantity < 1) {
      _quantity = 1;
    }

    _quantityController.value = TextEditingValue(
      text: '$_quantity',
      selection: TextSelection.collapsed(offset: '$_quantity'.length),
    );
  }

  void _commitQuantityInput() {
    final rawValue = _quantityController.text.trim();
    final parsedValue = int.tryParse(rawValue) ?? _quantity;
    final stockLimit = _stockLimit;

    var nextQuantity = parsedValue < 1 ? 1 : parsedValue;
    if (stockLimit != null && stockLimit > 0 && nextQuantity > stockLimit) {
      nextQuantity = stockLimit;
    }

    if (stockLimit != null && stockLimit <= 0) {
      nextQuantity = 1;
    }

    if (_quantity == nextQuantity &&
        _quantityController.text == '$nextQuantity') {
      return;
    }

    setState(() {
      _quantity = nextQuantity;
      _quantityController.value = TextEditingValue(
        text: '$_quantity',
        selection: TextSelection.collapsed(offset: '$_quantity'.length),
      );
    });
  }

  void _increaseQuantity() {
    final stockLimit = _stockLimit;
    if (stockLimit != null && _quantity >= stockLimit) {
      return;
    }

    setState(() {
      _quantity += 1;
      _quantityController.value = TextEditingValue(
        text: '$_quantity',
        selection: TextSelection.collapsed(offset: '$_quantity'.length),
      );
    });
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) {
      return;
    }

    setState(() {
      _quantity -= 1;
      _quantityController.value = TextEditingValue(
        text: '$_quantity',
        selection: TextSelection.collapsed(offset: '$_quantity'.length),
      );
    });
  }

  String get _selectedOption =>
      (_selectedVariant?.attributeSummary ?? '').isNotEmpty
          ? _selectedVariant!.attributeSummary
          : 'Generic';

  Widget _buildVariantSelector(
    BuildContext context,
    ProductModel product,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Variant',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ..._attributeNames.map((attributeName) {
          final selectedValue = _selectedAttributes[attributeName];
          final values = _allValuesForAttribute(attributeName);
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attributeName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: values.map((value) {
                    final matchedVariant = _firstMatchingVariantFor(
                      attributeName,
                      value,
                    );
                    final isSelected = selectedValue == value;
                    final isEnabled =
                        matchedVariant != null &&
                        matchedVariant.availableQuantity > 0;
                    final variationPrice = matchedVariant == null
                        ? product.price
                        : product.priceForVariant(matchedVariant);

                    return ChoiceChip(
                      label: Text(
                        variationPrice != product.price
                            ? '$value  RM ${variationPrice.toStringAsFixed(2)}'
                            : value,
                      ),
                      selected: isSelected,
                      onSelected: isEnabled
                          ? (_) => _selectAttributeValue(attributeName, value)
                          : null,
                      selectedColor: colorScheme.primary,
                      disabledColor: colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isEnabled
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final product = widget.product;
    final stockLimit = _stockLimit;
    final isSoldOut = product.isSoldOut || (stockLimit != null && stockLimit <= 0);
    final displayPrice = product.priceForVariant(_selectedVariant);

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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            child: SingleChildScrollView(
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
                              'RM ${displayPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedOption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (product.variations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildVariantSelector(context, product),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Quantity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove_rounded,
                        onPressed: _quantity > 1 ? _decreaseQuantity : null,
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 76,
                        child: TextField(
                          controller: _quantityController,
                          focusNode: _quantityFocusNode,
                          enabled: !isSoldOut,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onSubmitted: (_) => _commitQuantityInput(),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _QuantityButton(
                        icon: Icons.add_rounded,
                        onPressed: isSoldOut ? null : _increaseQuantity,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSoldOut
                          ? null
                          : () {
                              _commitQuantityInput();
                              Navigator.pop(
                                context,
                                PurchaseSelection(
                                  quantity: _quantity,
                                  selectedOption: _selectedOption,
                                  selectedVariant: _selectedVariant,
                                ),
                              );
                            },
                      icon: Icon(widget.actionIcon),
                      label: Text(
                        isSoldOut ? 'Sold Out' : widget.actionLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, this.onPressed});

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
