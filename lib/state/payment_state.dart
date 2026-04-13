import '../models/payment_model.dart';
import '../services/auth/auth_service.dart';
import '../services/payment/stripe_service.dart';
import 'entity_state.dart';

class PaymentState extends EntityState<PaymentModel> {
  PaymentState({
    StripeService? stripeService,
    AuthService? authService,
  }) : _stripeService = stripeService ?? StripeService(),
       _authService = authService ?? AuthService();

  final StripeService _stripeService;
  final AuthService _authService;

  Future<StripePaymentResult> payWithCard(double amount) async {
    setLoading(true);
    setError(null);

    try {
      return await _stripeService.payWithCard(amount: amount);
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<PaymentModel> createPaymentRecord({
    required String orderId,
    required double amount,
    required String paymentMethod,
    required String paymentStatus,
    String? transactionId,
    Map<String, dynamic>? gatewayResponse,
  }) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('A logged-in user is required to save payment details.');
    }

    setLoading(true);
    setError(null);

    try {
      final payment = await _stripeService.createPaymentRecord(
        orderId: orderId,
        userId: userId,
        amount: amount,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        transactionId: transactionId,
        gatewayResponse: gatewayResponse,
      );
      upsertItem(payment);
      return payment;
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}
