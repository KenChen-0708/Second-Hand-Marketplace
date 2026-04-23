import 'dart:convert';

import 'json_utils.dart';
import 'seller_follow_model.dart';
import 'user_model.dart';

class FollowingSellerItemModel {
  const FollowingSellerItemModel({
    required this.follow,
    required this.seller,
  });

  final SellerFollowModel follow;
  final UserModel seller;

  factory FollowingSellerItemModel.fromMap(Map<String, dynamic> map) {
    final sellerMap = JsonUtils.asMap(map['seller']);
    if (sellerMap == null) {
      throw Exception('Following item is missing seller data.');
    }

    return FollowingSellerItemModel(
      follow: SellerFollowModel.fromMap(map),
      seller: UserModel.fromMap(sellerMap),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...follow.toMap(),
      'seller': seller.toMap(),
    };
  }

  factory FollowingSellerItemModel.fromJson(String source) =>
      FollowingSellerItemModel.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  String toJson() => json.encode(toMap());
}
