import 'dart:convert';

import 'app_model.dart';
import 'json_utils.dart';
import 'product_model.dart';
import 'product_variation_model.dart';

class CartModel implements AppModel {
  @override
  final String id;
  final ProductModel product;
  final ProductVariationModel? selectedVariant;
  final int quantity;
  final DateTime? addedAt;

  const CartModel({
    required this.id,
    required this.product,
    this.selectedVariant,
    this.quantity = 1,
    this.addedAt,
  });

  double get unitPrice => product.priceForVariant(selectedVariant);
  double get totalPrice => unitPrice * quantity;
  String? get variantLabel => selectedVariant?.attributeSummary;

  CartModel copyWith({
    String? id,
    ProductModel? product,
    ProductVariationModel? selectedVariant,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartModel(
      id: id ?? this.id,
      product: product ?? this.product,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  factory CartModel.fromMap(Map<String, dynamic> map) {
    return CartModel(
      id: JsonUtils.asString(map['id']) ?? '',
      product: ProductModel.fromMap(
        (map['product'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      selectedVariant: map['selected_variant'] == null
          ? null
          : ProductVariationModel.fromMap(
              (map['selected_variant'] as Map).cast<String, dynamic>(),
            ),
      quantity: JsonUtils.asInt(map['quantity']) ?? 1,
      addedAt: JsonUtils.asDateTime(map['added_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product': product.toMap(),
      'selected_variant': selectedVariant?.toMap(),
      'quantity': quantity,
      'added_at': addedAt?.toIso8601String(),
    };
  }

  factory CartModel.fromJson(String source) =>
      CartModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
