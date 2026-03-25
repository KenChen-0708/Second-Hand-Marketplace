import 'package:flutter/foundation.dart';

import '../models/cart_model.dart';
import '../models/order_item_model.dart';
import '../models/product_model.dart';

class CartState extends ChangeNotifier {
  final List<CartModel> _items = [];

  List<CartModel> get items => List.unmodifiable(_items);
  List<CartModel> get cartItems => items;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get totalItems => _items.length;
  int get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal =>
      _items.fold(0, (sum, item) => sum + item.totalPrice);
  double get totalPrice => subtotal;

  bool containsProduct(String productId) =>
      _items.any((item) => item.product.id == productId);

  double getItemSubtotal(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return 0;
    return _items[index].totalPrice;
  }

  void addToCart(ProductModel product, {int quantity = 1}) {
    if (quantity <= 0) return;

    final index = _items.indexWhere((item) => item.product.id == product.id);

    if (index == -1) {
      _items.add(
        CartModel(
          id: product.id,
          product: product,
          quantity: quantity,
          addedAt: DateTime.now(),
        ),
      );
    } else {
      final currentItem = _items[index];
      _items[index] = currentItem.copyWith(
        quantity: currentItem.quantity + quantity,
      );
    }

    notifyListeners();
  }

  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;

    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }

    notifyListeners();
  }

  void increaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;

    updateQuantity(productId, _items[index].quantity + 1);
  }

  void decreaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;

    updateQuantity(productId, _items[index].quantity - 1);
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  List<OrderItemModel> toOrderItems() {
    return _items
        .map(
          (item) => OrderItemModel(
            id: item.id,
            productId: item.product.id,
            sellerId: item.product.sellerId,
            quantity: item.quantity,
            unitPrice: item.product.price,
            totalPrice: item.totalPrice,
          ),
        )
        .toList();
  }
}
