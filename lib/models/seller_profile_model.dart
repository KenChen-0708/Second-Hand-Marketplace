import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class SellerProfileModel implements AppModel {
  @override
  final String id;
  final String userId;
  final int totalSales;
  final double averageRating;
  final int totalReviews;
  final String? responseTime;
  final int totalProducts;
  final bool isVerified;
  final DateTime? verificationDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SellerProfileModel({
    required this.id,
    required this.userId,
    this.totalSales = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.responseTime,
    this.totalProducts = 0,
    this.isVerified = false,
    this.verificationDate,
    this.createdAt,
    this.updatedAt,
  });

  SellerProfileModel copyWith({
    String? id,
    String? userId,
    int? totalSales,
    double? averageRating,
    int? totalReviews,
    String? responseTime,
    int? totalProducts,
    bool? isVerified,
    DateTime? verificationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SellerProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalSales: totalSales ?? this.totalSales,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      responseTime: responseTime ?? this.responseTime,
      totalProducts: totalProducts ?? this.totalProducts,
      isVerified: isVerified ?? this.isVerified,
      verificationDate: verificationDate ?? this.verificationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SellerProfileModel.fromMap(Map<String, dynamic> map) {
    return SellerProfileModel(
      id: JsonUtils.asString(map['id']) ?? '',
      userId: JsonUtils.asString(map['user_id']) ?? '',
      totalSales: JsonUtils.asInt(map['total_sales']) ?? 0,
      averageRating: JsonUtils.asDouble(map['average_rating']) ?? 0,
      totalReviews: JsonUtils.asInt(map['total_reviews']) ?? 0,
      responseTime: JsonUtils.asString(map['response_time']),
      totalProducts: JsonUtils.asInt(map['total_products']) ?? 0,
      isVerified: JsonUtils.asBool(map['is_verified']) ?? false,
      verificationDate: JsonUtils.asDateTime(map['verification_date']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'total_sales': totalSales,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'response_time': responseTime,
      'total_products': totalProducts,
      'is_verified': isVerified,
      'verification_date': verificationDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SellerProfileModel.fromJson(String source) =>
      SellerProfileModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}