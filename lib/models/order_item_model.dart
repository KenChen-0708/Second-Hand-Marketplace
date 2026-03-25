import 'dart:convert';

import 'app_model.dart';
import 'json_utils.dart';

class OrderItemModel implements AppModel {
  @override
  final String id;
  final String? orderId;
  final String productId;
  final String sellerId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const OrderItemModel({
    required this.id,
    this.orderId,
    required this.productId,
    required this.sellerId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? sellerId,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      sellerId: sellerId ?? this.sellerId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderId: JsonUtils.asString(map['order_id']),
      productId: JsonUtils.asString(map['product_id']) ?? '',
      sellerId: JsonUtils.asString(map['seller_id']) ?? '',
      quantity: JsonUtils.asInt(map['quantity']) ?? 1,
      unitPrice: JsonUtils.asDouble(map['unit_price']) ?? 0,
      totalPrice: JsonUtils.asDouble(map['total_price']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'seller_id': sellerId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory OrderItemModel.fromJson(String source) =>
      OrderItemModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
