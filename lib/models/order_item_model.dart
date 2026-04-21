import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';
import 'product_model.dart';
import 'product_variation_model.dart';

class OrderItemModel implements AppModel {
  @override
  final String id;
  final String? orderId;
  final String productId;
  final String? variantId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final ProductModel? product;
  final ProductVariationModel? variant;

  const OrderItemModel({
    required this.id,
    this.orderId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.product,
    this.variant,
  });

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? variantId,
    int? quantity,
    double? unitPrice,
    double? subtotal,
    ProductModel? product,
    ProductVariationModel? variant,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      product: product ?? this.product,
      variant: variant ?? this.variant,
    );
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderId: JsonUtils.asString(map['order_id']),
      productId: JsonUtils.asString(map['product_id']) ?? '',
      variantId: JsonUtils.asString(map['variant_id']),
      quantity: JsonUtils.asInt(map['quantity']) ?? 1,
      unitPrice: JsonUtils.asDouble(map['unit_price']) ?? 0,
      subtotal: JsonUtils.asDouble(map['subtotal']) ?? 0,
      product: map['products'] != null
          ? ProductModel.fromMap(Map<String, dynamic>.from(map['products']))
          : null,
      variant: map['variant'] != null
          ? ProductVariationModel.fromMap(
              Map<String, dynamic>.from(map['variant']),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'products': product?.toMap(),
      'variant': variant?.toMap(),
    };
  }

  factory OrderItemModel.fromJson(String source) =>
      OrderItemModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
