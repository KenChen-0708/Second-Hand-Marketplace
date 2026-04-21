import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';
import 'product_variation_model.dart';

class ProductModel implements AppModel {
  @override
  final String id;
  final String title;
  final String description;
  final double price;
  final String? categoryId;
  final String sellerId;
  final String? sellerName;
  final String condition;
  final String? imageUrl;
  final List<String>? images;
  final List<String> tradePreference;
  final int? totalStock;
  final int? availableQuantity;
  final List<ProductVariationModel> variations;
  final bool openToOffers;
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
    this.sellerName,
    required this.condition,
    this.imageUrl,
    this.images,
    this.status = 'active',
    this.tradePreference = const ['face_to_face'],
    this.totalStock,
    this.availableQuantity,
    this.variations = const [],
    this.openToOffers = false,
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
    String? sellerName,
    String? condition,
    String? imageUrl,
    List<String>? images,
    String? status,
    List<String>? tradePreference,
    int? totalStock,
    int? availableQuantity,
    List<ProductVariationModel>? variations,
    bool? openToOffers,
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
      sellerName: sellerName ?? this.sellerName,
      condition: condition ?? this.condition,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      status: status ?? this.status,
      tradePreference: tradePreference ?? this.tradePreference,
      totalStock: totalStock ?? this.totalStock,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      variations: variations ?? this.variations,
      openToOffers: openToOffers ?? this.openToOffers,
      viewCount: viewCount ?? this.viewCount,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    final parsedVariations = (map['variations'] as List? ?? const [])
        .map(
          (item) => ProductVariationModel.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final parsedPrice =
        JsonUtils.asDouble(map['price']) ??
        JsonUtils.asDouble(map['base_price']) ??
        0;
    final parsedAvailableQuantity =
        JsonUtils.asInt(map['total_stock']) ??
        JsonUtils.asInt(map['available_quantity']) ??
        JsonUtils.asInt(map['quantity']) ??
        (parsedVariations.isNotEmpty
            ? parsedVariations.fold<int>(
                0,
                (sum, variation) => sum + variation.availableQuantity,
              )
            : null);

    return ProductModel(
      id: JsonUtils.asString(map['id']) ?? '',
      title: JsonUtils.asString(map['title']) ?? '',
      description: JsonUtils.asString(map['description']) ?? '',
      price: parsedPrice,
      categoryId: JsonUtils.asString(map['category_id']),
      sellerId: JsonUtils.asString(map['seller_id']) ?? '',
      sellerName: map['seller'] != null
          ? JsonUtils.asString(map['seller']['name'])
          : null,
      condition: JsonUtils.asString(map['condition']) ?? '',
      imageUrl:
          JsonUtils.asString(map['image_url']) ??
          (JsonUtils.asStringList(map['image_urls'])?.isNotEmpty == true
              ? JsonUtils.asStringList(map['image_urls'])![0]
              : null),
      images: JsonUtils.asStringList(map['image_urls']),
      status: JsonUtils.asString(map['status']) ?? 'active',
      tradePreference:
          JsonUtils.asStringList(map['trade_preference']) ??
          (JsonUtils.asString(map['trade_preference']) != null
              ? [JsonUtils.asString(map['trade_preference'])!]
              : const ['face_to_face']),
      totalStock: JsonUtils.asInt(map['total_stock']) ?? parsedAvailableQuantity,
      availableQuantity: parsedAvailableQuantity,
      variations: parsedVariations,
      openToOffers: map['open_to_offers'] == true,
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
      'base_price': price,
      'category_id': categoryId,
      'seller_id': sellerId,
      'seller': sellerName != null ? {'name': sellerName} : null,
      'condition': condition,
      'image_url': imageUrl,
      'image_urls': images,
      'status': status,
      'trade_preference': tradePreference,
      'total_stock': totalStock ?? availableQuantity,
      'available_quantity': availableQuantity,
      'variations': variations.map((variation) => variation.toMap()).toList(),
      'open_to_offers': openToOffers,
      'view_count': viewCount,
      'likes_count': likesCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ProductModel.fromJson(String source) =>
      ProductModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());

  bool get hasVariants => variations.isNotEmpty;

  double priceForVariant(ProductVariationModel? variant) {
    if (variant == null) {
      return price;
    }
    return variant.effectivePrice(price);
  }

  int? get stockQuantity {
    if (hasVariants) {
      return variations.fold<int>(
        0,
        (sum, variation) => sum + variation.availableQuantity,
      );
    }
    return totalStock ?? availableQuantity;
  }

  bool get isSoldOut {
    final normalizedStatus = status.toLowerCase();
    if (normalizedStatus == 'sold' || normalizedStatus == 'inactive') {
      return true;
    }

    final quantity = stockQuantity;
    return quantity != null && quantity <= 0;
  }
}
