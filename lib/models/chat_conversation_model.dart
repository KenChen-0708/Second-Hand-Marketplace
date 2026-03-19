import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class ChatConversationModel implements AppModel {
  @override
  final String id;
  final String productId;
  final String buyerId;
  final String sellerId;
  final bool dealAgreed;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatConversationModel({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    this.dealAgreed = false,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  ChatConversationModel copyWith({
    String? id,
    String? productId,
    String? buyerId,
    String? sellerId,
    bool? dealAgreed,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatConversationModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      dealAgreed: dealAgreed ?? this.dealAgreed,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ChatConversationModel.fromMap(Map<String, dynamic> map) {
    return ChatConversationModel(
      id: JsonUtils.asString(map['id']) ?? '',
      productId: JsonUtils.asString(map['product_id']) ?? '',
      buyerId: JsonUtils.asString(map['buyer_id']) ?? '',
      sellerId: JsonUtils.asString(map['seller_id']) ?? '',
      dealAgreed: JsonUtils.asBool(map['deal_agreed']) ?? false,
      lastMessageAt: JsonUtils.asDateTime(map['last_message_at']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'deal_agreed': dealAgreed,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ChatConversationModel.fromJson(String source) =>
      ChatConversationModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}