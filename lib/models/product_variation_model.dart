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
  final double? price;
  final String? sku;
  final Map<String, String> attributes;
  final DateTime? createdAt;

  const ProductVariationModel({
    required this.id,
    required this.productId,
    required this.variationType,
    required this.variationValue,
    this.availableQuantity = 0,
    this.priceAdjustment = 0,
    this.price,
    this.sku,
    this.attributes = const {},
    this.createdAt,
  });

  ProductVariationModel copyWith({
    String? id,
    String? productId,
    String? variationType,
    String? variationValue,
    int? availableQuantity,
    double? priceAdjustment,
    double? price,
    String? sku,
    Map<String, String>? attributes,
    DateTime? createdAt,
  }) {
    return ProductVariationModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variationType: variationType ?? this.variationType,
      variationValue: variationValue ?? this.variationValue,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      priceAdjustment: priceAdjustment ?? this.priceAdjustment,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      attributes: attributes ?? this.attributes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get label => '$variationType: $variationValue';

  Map<String, String> get normalizedAttributes {
    if (attributes.isNotEmpty) {
      final entries = attributes.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return {for (final entry in entries) entry.key: entry.value};
    }

    if (variationType.isNotEmpty && variationValue.isNotEmpty) {
      return {variationType: variationValue};
    }

    return const {};
  }

  factory ProductVariationModel.fromMap(Map<String, dynamic> map) {
    final rawAttributes = map['attributes'] as List? ?? const [];
    final attributes = <String, String>{};
    for (final item in rawAttributes) {
      final attributeMap = Map<String, dynamic>.from(item as Map);
      final name = JsonUtils.asString(attributeMap['attribute_name']) ?? '';
      final value = JsonUtils.asString(attributeMap['attribute_value']) ?? '';
      if (name.isNotEmpty && value.isNotEmpty) {
        attributes[name] = value;
      }
    }

    final legacyType = JsonUtils.asString(map['variation_type']);
    final legacyValue = JsonUtils.asString(map['variation_value']);
    final derivedEntries = attributes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final derivedType =
        derivedEntries.map((entry) => entry.key).join(' / ');
    final derivedValue =
        derivedEntries.map((entry) => entry.value).join(' / ');

    return ProductVariationModel(
      id: JsonUtils.asString(map['id']) ?? '',
      productId: JsonUtils.asString(map['product_id']) ?? '',
      variationType: legacyType ?? derivedType,
      variationValue: legacyValue ?? derivedValue,
      availableQuantity:
          JsonUtils.asInt(map['available_quantity']) ??
          JsonUtils.asInt(map['quantity']) ??
          0,
      priceAdjustment: JsonUtils.asDouble(map['price_adjustment']) ?? 0,
      price: JsonUtils.asDouble(map['price']),
      sku: JsonUtils.asString(map['sku']),
      attributes: attributes,
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
      'price': price,
      'sku': sku,
      'attributes': attributes.entries
          .map(
            (entry) => {
              'attribute_name': entry.key,
              'attribute_value': entry.value,
            },
          )
          .toList(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory ProductVariationModel.fromJson(String source) =>
      ProductVariationModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());

  double effectivePrice(double basePrice) => price ?? (basePrice + priceAdjustment);

  String get attributeSummary {
    final normalized = normalizedAttributes;
    if (normalized.isEmpty) {
      return label;
    }

    final entries = normalized.entries.toList();
    return entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
  }

  String get optionSummary {
    final normalized = normalizedAttributes;
    if (normalized.isEmpty) {
      return variationValue.isNotEmpty ? variationValue : label;
    }

    return normalized.values.join(' / ');
  }
}
