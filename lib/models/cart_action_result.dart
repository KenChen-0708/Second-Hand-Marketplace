import 'cart_model.dart';

class CartActionResult {
  const CartActionResult({
    required this.success,
    required this.message,
    this.item,
  });

  final bool success;
  final String message;
  final CartModel? item;
}
