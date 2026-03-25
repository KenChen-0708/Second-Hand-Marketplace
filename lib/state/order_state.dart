import '../models/order_model.dart';
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

  Future<List<OrderModel>> checkout({
    required CartState cartState,
    String? handoverLocation,
    DateTime? handoverDate,
    String? notes,
  }) async {
    if (cartState.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final buyerId = _authService.getCurrentUserId();
    if (buyerId == null || buyerId.isEmpty) {
      throw Exception('A logged-in user is required to checkout.');
    }

    setLoading(true);
    setError(null);

    try {
      final orders = await _orderService.createOrder(
        buyerId: buyerId,
        orderItems: cartState.toOrderItems(),
        handoverLocation: handoverLocation,
        handoverDate: handoverDate,
        notes: notes,
      );

      addItems(orders);
      _lastCheckoutOrders = orders;
      _lastOrderNumber = orders.isNotEmpty ? orders.first.orderNumber : null;
      await cartState.clearCart();
      return orders;
    } catch (e) {
      setError(e.toString());
      rethrow;
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
