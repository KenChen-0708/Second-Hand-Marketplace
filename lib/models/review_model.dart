import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class ReviewModel implements AppModel {
  @override
  final String id;
  final String orderId;
  final String reviewerId;
  final String revieweeId;
  final String productId;
  final int rating;
  final String? title;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.reviewerId,
    required this.revieweeId,
    required this.productId,
    required this.rating,
    this.title,
    this.comment,
    this.createdAt,
    this.updatedAt,
  });

  ReviewModel copyWith({
    String? id,
    String? orderId,
    String? reviewerId,
    String? revieweeId,
    String? productId,
    int? rating,
    String? title,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      reviewerId: reviewerId ?? this.reviewerId,
      revieweeId: revieweeId ?? this.revieweeId,
      productId: productId ?? this.productId,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderId: JsonUtils.asString(map['order_id']) ?? '',
      reviewerId: JsonUtils.asString(map['reviewer_id']) ?? '',
      revieweeId: JsonUtils.asString(map['reviewee_id']) ?? '',
      productId: JsonUtils.asString(map['product_id']) ?? '',
      rating: JsonUtils.asInt(map['rating']) ?? 0,
      title: JsonUtils.asString(map['title']),
      comment: JsonUtils.asString(map['comment']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'product_id': productId,
      'rating': rating,
      'title': title,
      'comment': comment,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ReviewModel.fromJson(String source) =>
      ReviewModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}