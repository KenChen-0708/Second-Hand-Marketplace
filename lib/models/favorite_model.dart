import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class FavoriteModel implements AppModel {
  @override
  final String id;
  final String userId;
  final String productId;
  final DateTime? createdAt;

  const FavoriteModel({
    required this.id,
    required this.userId,
    required this.productId,
    this.createdAt,
  });

  FavoriteModel copyWith({
    String? id,
    String? userId,
    String? productId,
    DateTime? createdAt,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FavoriteModel.fromMap(Map<String, dynamic> map) {
    return FavoriteModel(
      id: JsonUtils.asString(map['id']) ?? '',
      userId: JsonUtils.asString(map['user_id']) ?? '',
      productId: JsonUtils.asString(map['product_id']) ?? '',
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory FavoriteModel.fromJson(String source) =>
      FavoriteModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}