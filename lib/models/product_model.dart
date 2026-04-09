import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class ProductModel implements AppModel {
  @override
  final String id;
  final String title;
  final String description;
  final double price;
  final String? categoryId;
  final String sellerId;
  final String condition;
  final String? imageUrl;
  final List<String>? images;
  final String status;
  final int viewCount;
  final int likesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.categoryId,
    required this.sellerId,
    required this.condition,
    this.imageUrl,
    this.images,
    this.status = 'active',
    this.viewCount = 0,
    this.likesCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  ProductModel copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? categoryId,
    String? sellerId,
    String? condition,
    String? imageUrl,
    List<String>? images,
    String? status,
    int? viewCount,
    int? likesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      sellerId: sellerId ?? this.sellerId,
      condition: condition ?? this.condition,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      status: status ?? this.status,
      viewCount: viewCount ?? this.viewCount,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: JsonUtils.asString(map['id']) ?? '',
      title: JsonUtils.asString(map['title']) ?? '',
      description: JsonUtils.asString(map['description']) ?? '',
      price: JsonUtils.asDouble(map['price']) ?? 0,
      categoryId: JsonUtils.asString(map['category_id']),
      sellerId: JsonUtils.asString(map['seller_id']) ?? '',
      condition: JsonUtils.asString(map['condition']) ?? '',
      imageUrl: JsonUtils.asString(map['image_url']) ?? 
          (JsonUtils.asStringList(map['image_urls'])?.isNotEmpty == true ? JsonUtils.asStringList(map['image_urls'])![0] : null),
      images: JsonUtils.asStringList(map['image_urls']),
      status: JsonUtils.asString(map['status']) ?? 'active',
      viewCount: JsonUtils.asInt(map['view_count']) ?? 0,
      likesCount: JsonUtils.asInt(map['likes_count']) ?? 0,
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'seller_id': sellerId,
      'condition': condition,
      'image_url': imageUrl,
      'image_urls': images,
      'status': status,
      'view_count': viewCount,
      'likes_count': likesCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ProductModel.fromJson(String source) =>
      ProductModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}