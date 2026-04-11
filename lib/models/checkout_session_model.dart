import 'dart:convert';

import 'cart_model.dart';

class CheckoutSessionModel {
  const CheckoutSessionModel({
    required this.items,
    this.clearCartAfterSuccess = false,
    this.isBuyNow = false,
  });

  final List<CartModel> items;
  final bool clearCartAfterSuccess;
  final bool isBuyNow;

  CheckoutSessionModel copyWith({
    List<CartModel>? items,
    bool? clearCartAfterSuccess,
    bool? isBuyNow,
  }) {
    return CheckoutSessionModel(
      items: items ?? this.items,
      clearCartAfterSuccess: clearCartAfterSuccess ?? this.clearCartAfterSuccess,
      isBuyNow: isBuyNow ?? this.isBuyNow,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
      'clear_cart_after_success': clearCartAfterSuccess,
      'is_buy_now': isBuyNow,
    };
  }

  factory CheckoutSessionModel.fromMap(Map<String, dynamic> map) {
    return CheckoutSessionModel(
      items: (map['items'] as List? ?? const [])
          .map((item) => CartModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      clearCartAfterSuccess: map['clear_cart_after_success'] == true,
      isBuyNow: map['is_buy_now'] == true,
    );
  }

  factory CheckoutSessionModel.fromJson(String source) =>
      CheckoutSessionModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
