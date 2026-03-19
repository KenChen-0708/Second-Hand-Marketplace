import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class CartItemModel implements AppModel {
  @override
  final String id;
  final String userId;
  final String productId;
  final int quantity;
  final DateTime? addedAt;

  const CartItemModel({
    required this.id,
    required this.userId,
    required this.productId,
    this.quantity = 1,
    this.addedAt,
  });

  CartItemModel copyWith({
    String? id,
    String? userId,
    String? productId,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      id: JsonUtils.asString(map['id']) ?? '',
      userId: JsonUtils.asString(map['user_id']) ?? '',
      productId: JsonUtils.asString(map['product_id']) ?? '',
      quantity: JsonUtils.asInt(map['quantity']) ?? 1,
      addedAt: JsonUtils.asDateTime(map['added_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'added_at': addedAt?.toIso8601String(),
    };
  }

  factory CartItemModel.fromJson(String source) =>
      CartItemModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}