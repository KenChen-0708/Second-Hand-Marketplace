import 'dart:convert';

import 'app_model.dart';
import 'json_utils.dart';

class OrderItemModel implements AppModel {
  @override
  final String id;
  final String? orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const OrderItemModel({
    required this.id,
    this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    int? quantity,
    double? unitPrice,
    double? subtotal,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
    );
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderId: JsonUtils.asString(map['order_id']),
      productId: JsonUtils.asString(map['product_id']) ?? '',
      quantity: JsonUtils.asInt(map['quantity']) ?? 1,
      unitPrice: JsonUtils.asDouble(map['unit_price']) ?? 0,
      subtotal: JsonUtils.asDouble(map['subtotal']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }

  factory OrderItemModel.fromJson(String source) =>
      OrderItemModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
