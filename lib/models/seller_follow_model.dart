import 'dart:convert';

import 'app_model.dart';
import 'json_utils.dart';

class SellerFollowModel implements AppModel {
  @override
  final String id;
  final String userId;
  final String sellerId;
  final DateTime? createdAt;

  const SellerFollowModel({
    required this.id,
    required this.userId,
    required this.sellerId,
    this.createdAt,
  });

  SellerFollowModel copyWith({
    String? id,
    String? userId,
    String? sellerId,
    DateTime? createdAt,
  }) {
    return SellerFollowModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sellerId: sellerId ?? this.sellerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SellerFollowModel.fromMap(Map<String, dynamic> map) {
    return SellerFollowModel(
      id: JsonUtils.asString(map['id']) ?? '',
      userId: JsonUtils.asString(map['user_id']) ?? '',
      sellerId: JsonUtils.asString(map['seller_id']) ?? '',
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'seller_id': sellerId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory SellerFollowModel.fromJson(String source) =>
      SellerFollowModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
