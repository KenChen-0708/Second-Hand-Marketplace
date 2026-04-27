import 'dart:convert';

import 'json_utils.dart';
import 'seller_follow_model.dart';
import 'user_model.dart';

class FollowerItemModel {
  const FollowerItemModel({
    required this.follow,
    required this.follower,
  });

  final SellerFollowModel follow;
  final UserModel follower;

  factory FollowerItemModel.fromMap(Map<String, dynamic> map) {
    final followerMap = JsonUtils.asMap(map['follower']);
    if (followerMap == null) {
      throw Exception('Follower item is missing follower data.');
    }

    return FollowerItemModel(
      follow: SellerFollowModel.fromMap(map),
      follower: UserModel.fromMap(followerMap),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...follow.toMap(),
      'follower': follower.toMap(),
    };
  }

  factory FollowerItemModel.fromJson(String source) =>
      FollowerItemModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
