import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class AppNotificationModel implements AppModel {
  @override
  final String id;
  final String userId;
  final String title;
  final String message;
  final String? notificationType;
  final String? relatedOrderId;
  final String? relatedProductId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.notificationType,
    this.relatedOrderId,
    this.relatedProductId,
    this.isRead = false,
    this.createdAt,
  });

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? notificationType,
    String? relatedOrderId,
    String? relatedProductId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      relatedOrderId: relatedOrderId ?? this.relatedOrderId,
      relatedProductId: relatedProductId ?? this.relatedProductId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map) {
    return AppNotificationModel(
      id: JsonUtils.asString(map['id']) ?? '',
      userId: JsonUtils.asString(map['user_id']) ?? '',
      title: JsonUtils.asString(map['title']) ?? '',
      message: JsonUtils.asString(map['message']) ?? '',
      notificationType: JsonUtils.asString(map['notification_type']),
      relatedOrderId: JsonUtils.asString(map['related_order_id']),
      relatedProductId: JsonUtils.asString(map['related_product_id']),
      isRead: JsonUtils.asBool(map['is_read']) ?? false,
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'related_order_id': relatedOrderId,
      'related_product_id': relatedProductId,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory AppNotificationModel.fromJson(String source) =>
      AppNotificationModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}