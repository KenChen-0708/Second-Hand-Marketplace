import '../models/models.dart';
import '../services/auth/auth_service.dart';
import '../services/order/order_service.dart';
import 'cart_state.dart';
import 'entity_state.dart';

class OrderState extends EntityState<OrderModel> {
  OrderState({
    OrderService? orderService,
    AuthService? authService,
  }) : _orderService = orderService ?? OrderService(),
       _authService = authService ?? AuthService();

  final OrderService _orderService;
  final AuthService _authService;

  List<OrderModel> _lastCheckoutOrders = [];
  String? _lastOrderNumber;

  List<OrderModel> get lastCheckoutOrders =>
      List.unmodifiable(_lastCheckoutOrders);
  String? get lastOrderNumber => _lastOrderNumber;

  Future<List<OrderModel>> checkoutItems({
    required List<CartModel> items,
    CartState? cartState,
    bool clearCartAfterSuccess = false,
    String? handoverLocation,
    DateTime? handoverDate,
    String? notes,
    String status = 'pending',
    String paymentStatus = 'pending',
  }) async {
    if (items.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final buyerId = await _authService.getCurrentUserId();
    if (buyerId == null || buyerId.isEmpty) {
      throw Exception('A logged-in user is required to checkout.');
    }

    setLoading(true);
    setError(null);

    try {
      final orders = await _orderService.createOrder(
        buyerId: buyerId,
        orderItems: items
            .map(
              (item) => OrderItemModel(
                id: item.id,
                productId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.product.price,
                subtotal: item.totalPrice,
              ),
            )
            .toList(),
        handoverLocation: handoverLocation,
        handoverDate: handoverDate,
        notes: notes,
        status: status,
        paymentStatus: paymentStatus,
      );

      addItems(orders);
      _lastCheckoutOrders = orders;
      _lastOrderNumber = orders.isNotEmpty ? orders.first.orderNumber : null;
      if (clearCartAfterSuccess && cartState != null) {
        await cartState.clearCart();
      }
      return orders;
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<List<OrderModel>> checkout({
    required CartState cartState,
    String? handoverLocation,
    DateTime? handoverDate,
    String? notes,
  }) async {
    return checkoutItems(
      items: cartState.items,
      cartState: cartState,
      clearCartAfterSuccess: true,
      handoverLocation: handoverLocation,
      handoverDate: handoverDate,
      notes: notes,
    );
  }

  Future<void> fetchUserOrders(String userId) async {
    setLoading(true);
    setError(null);
    try {
      final orders = await _orderService.getUserOrders(userId);
      setItems(orders);
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  void clearCheckoutState() {
    _lastCheckoutOrders = [];
    _lastOrderNumber = null;
    clearError();
    notifyListeners();
  }
}
