import 'dart:convert';

import 'app_model.dart';
import 'json_utils.dart';

class ProductVariationModel implements AppModel {
  @override
  final String id;
  final String productId;
  final String variationType;
  final String variationValue;
  final int availableQuantity;
  final double priceAdjustment;
  final DateTime? createdAt;

  const ProductVariationModel({
    required this.id,
    required this.productId,
    required this.variationType,
    required this.variationValue,
    this.availableQuantity = 0,
    this.priceAdjustment = 0,
    this.createdAt,
  });

  ProductVariationModel copyWith({
    String? id,
    String? productId,
    String? variationType,
    String? variationValue,
    int? availableQuantity,
    double? priceAdjustment,
    DateTime? createdAt,
  }) {
    return ProductVariationModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variationType: variationType ?? this.variationType,
      variationValue: variationValue ?? this.variationValue,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      priceAdjustment: priceAdjustment ?? this.priceAdjustment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get label => '$variationType: $variationValue';

  factory ProductVariationModel.fromMap(Map<String, dynamic> map) {
    return ProductVariationModel(
      id: JsonUtils.asString(map['id']) ?? '',
      productId: JsonUtils.asString(map['product_id']) ?? '',
      variationType: JsonUtils.asString(map['variation_type']) ?? '',
      variationValue: JsonUtils.asString(map['variation_value']) ?? '',
      availableQuantity: JsonUtils.asInt(map['available_quantity']) ?? 0,
      priceAdjustment: JsonUtils.asDouble(map['price_adjustment']) ?? 0,
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'variation_type': variationType,
      'variation_value': variationValue,
      'available_quantity': availableQuantity,
      'price_adjustment': priceAdjustment,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory ProductVariationModel.fromJson(String source) =>
      ProductVariationModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
