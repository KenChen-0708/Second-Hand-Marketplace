import 'dart:convert';

import 'favorite_model.dart';
import 'json_utils.dart';
import 'product_model.dart';

class WishlistItemModel {
  const WishlistItemModel({
    required this.favorite,
    required this.product,
  });

  final FavoriteModel favorite;
  final ProductModel product;

  factory WishlistItemModel.fromMap(Map<String, dynamic> map) {
    final productMap = JsonUtils.asMap(map['products']);
    if (productMap == null) {
      throw Exception('Wishlist item is missing product data.');
    }

    return WishlistItemModel(
      favorite: FavoriteModel.fromMap(map),
      product: ProductModel.fromMap(productMap),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...favorite.toMap(),
      'products': product.toMap(),
    };
  }

  factory WishlistItemModel.fromJson(String source) =>
      WishlistItemModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
