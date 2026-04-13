import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/auth/auth_service.dart';
import '../services/cart/cart_service.dart';

class CartState extends ChangeNotifier {
  CartState({
    CartService? cartService,
    AuthService? authService,
  }) : _cartService = cartService ?? CartService(),
       _authService = authService ?? AuthService() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      final authUserId = _authService.getCurrentAuthUserId();
      if (authUserId == null || authUserId.isEmpty) {
        _items.clear();
        _error = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      unawaited(loadCart());
    });

    if (_hasAuthenticatedUser) {
      unawaited(loadCart());
    }
  }

  final CartService _cartService;
  final AuthService _authService;
  late final StreamSubscription<AuthState> _authSubscription;
  final List<CartModel> _items = [];
  bool _isLoading = false;
  String? _error;

  List<CartModel> get items => List.unmodifiable(_items);
  List<CartModel> get cartItems => items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get totalItems => _items.length;
  int get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal =>
      _items.fold(0, (sum, item) => sum + item.totalPrice);
  double get totalPrice => subtotal;
  bool get _hasAuthenticatedUser {
    final authUserId = _authService.getCurrentAuthUserId();
    return authUserId != null && authUserId.isNotEmpty;
  }

  bool containsProduct(String productId) =>
      _items.any((item) => item.product.id == productId);

  double getItemSubtotal(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return 0;
    return _items[index].totalPrice;
  }

  Future<void> loadCart() async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      _items.clear();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final loadedItems = await _cartService.fetchCartItems(userId: userId);
      _items
        ..clear()
        ..addAll(loadedItems);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<CartActionResult> addToCart(
    ProductModel product, {
    int quantity = 1,
  }) async {
    if (product.id.isEmpty || quantity <= 0) {
      const result = CartActionResult(
        success: false,
        message: 'Please choose a valid item and quantity.',
      );
      _setError(result.message);
      return result;
    }

    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      const result = CartActionResult(
        success: false,
        message: 'Please log in to add items to your cart.',
      );
      _setError(result.message);
      return result;
    }

    _setLoading(true);
    _setError(null);

    try {
      final result = await _cartService.addToCart(
        userId: userId,
        product: product,
        quantity: quantity,
      );

      if (result.item != null) {
        _upsertLocalItem(result.item!);
      }

      notifyListeners();
      return result;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      final result = CartActionResult(
        success: false,
        message: message.isEmpty
            ? 'Failed to add item to cart, please try again.'
            : message,
      );
      _setError(result.message);
      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeFromCart(String productId) async {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }

    final cartItem = _items[index];
    _setLoading(true);
    _setError(null);

    try {
      await _cartService.removeCartItem(cartItemId: cartItem.id);
      _items.removeAt(index);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }

    final cartItem = _items[index];
    _setLoading(true);
    _setError(null);

    try {
      final updatedItem = await _cartService.updateCartItemQuantity(
        cartItemId: cartItem.id,
        product: cartItem.product,
        quantity: quantity,
      );

      if (updatedItem == null) {
        _items.removeAt(index);
      } else {
        _items[index] = updatedItem;
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> increaseQuantity(String productId) async {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }

    await updateQuantity(productId, _items[index].quantity + 1);
  }

  Future<void> decreaseQuantity(String productId) async {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }

    await updateQuantity(productId, _items[index].quantity - 1);
  }

  Future<void> clearCart() async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      _items.clear();
      _error = null;
      notifyListeners();
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _cartService.clearCart(userId: userId);
      _items.clear();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  List<OrderItemModel> toOrderItems() {
    return _items
        .map(
          (item) => OrderItemModel(
            id: item.id,
            productId: item.product.id,
            quantity: item.quantity,
            unitPrice: item.product.price,
            subtotal: item.totalPrice,
          ),
        )
        .toList();
  }

  void _upsertLocalItem(CartModel item) {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      _items.add(item);
      return;
    }

    _items[index] = item;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
