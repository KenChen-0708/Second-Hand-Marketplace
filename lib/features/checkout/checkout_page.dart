import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/payment/stripe_service.dart';
import '../../shared/utils/image_helper.dart';
import '../../state/state.dart';
import '../../shared/utils/snackbar_helper.dart';
import 'google_maps_picker.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, this.session});

  final CheckoutSessionModel? session;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _selectedPaymentMethod = 'Credit/Debit Card';
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isProcessing = false;
  late final List<CartModel> _checkoutItemsSnapshot;

  // Location fields
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';

  @override
  void initState() {
    super.initState();
    _checkoutItemsSnapshot = List<CartModel>.from(
      widget.session?.items ?? context.read<CartState>().items,
    );
    if (!StripeService.isSupportedPlatform) {
      _selectedPaymentMethod = 'Campus Wallet';
    }
  }

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);

    final cartState = context.read<CartState>();
    final orderState = context.read<OrderState>();
    final paymentState = context.read<PaymentState>();
    final checkoutItems = _checkoutItems;
    StripePaymentResult? stripeResult;

    try {
      if (_isCardPayment) {
        stripeResult = await paymentState.payWithCard(_totalAmount);
      }

      final orders = await orderState.checkoutItems(
        items: checkoutItems,
        cartState: widget.session?.clearCartAfterSuccess == true
            ? cartState
            : (widget.session == null ? cartState : null),
        clearCartAfterSuccess:
            widget.session?.clearCartAfterSuccess ?? widget.session == null,
        handoverLocation: _selectedAddress.isNotEmpty ? _selectedAddress : null,
        notes: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        status: _isCardPayment ? 'paid' : 'pending',
        paymentStatus: _isCardPayment ? 'paid' : 'pending',
      );

      if (!mounted) {
        return;
      }

      final createdOrder = orders.isNotEmpty ? orders.first : null;
      if (_isCardPayment && createdOrder != null) {
        await paymentState.createPaymentRecord(
          orderId: createdOrder.id,
          amount: _totalAmount,
          paymentMethod: _paymentMethodCode,
          paymentStatus: 'paid',
          transactionId: stripeResult?.paymentIntentId,
          gatewayResponse: stripeResult?.response,
        );
      }

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Order Confirmed!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your payment was successful. You can now track your order status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      context.pop();
                      context.pushReplacement(
                        '/profile/order-status',
                        extra: createdOrder,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Track Order',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      SnackbarHelper.showError(context, 'Checkout failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    context.watch<CartState>();
    final checkoutItems = _checkoutItems;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderSummary(context, checkoutItems),
                        const SizedBox(height: 20),
                        _buildPaymentMethod(context),
                        const SizedBox(height: 20),
                        _buildHandoverInstructions(context),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomButton(context, checkoutItems),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Checkout',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  List<CartModel> get _checkoutItems =>
      List.unmodifiable(_checkoutItemsSnapshot);

  double get _totalAmount =>
      _checkoutItems.fold<double>(0, (sum, item) => sum + item.totalPrice);

  bool get _isCardPayment => _selectedPaymentMethod == 'Credit/Debit Card';

  String get _paymentMethodCode {
    switch (_selectedPaymentMethod) {
      case 'Credit/Debit Card':
        return 'card';
      case 'Apple/Google Pay':
        return 'apple_google_pay';
      case 'Campus Wallet':
        return 'campus_wallet';
      default:
        return 'card';
    }
  }

  Widget _buildOrderSummary(
    BuildContext context,
    List<CartModel> checkoutItems,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (checkoutItems.isEmpty)
            const Text(
              'Your cart is empty.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...checkoutItems.map(
              (cartItem) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImageHelper.productImage(
                        cartItem.product.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cartItem.product.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '\$${cartItem.product.price.toStringAsFixed(2)} x ${cartItem.quantity}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                '\$${checkoutItems.fold<double>(0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Secure Payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 20),
          _buildPaymentOption('Credit/Debit Card', Icons.credit_card_rounded),
          _buildPaymentOption('Apple/Google Pay', Icons.apple_rounded),
          _buildPaymentOption(
            'Campus Wallet',
            Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String title, IconData icon) {
    final isSelected = _selectedPaymentMethod == title;
    final isCardOption = title == 'Credit/Debit Card';
    final isDisabled = isCardOption && !StripeService.isSupportedPlatform;

    return InkWell(
      onTap: isDisabled
          ? () => SnackbarHelper.showInfo(
              context,
              'Card payments are available on mobile devices only.',
            )
          : () => setState(() => _selectedPaymentMethod = title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDisabled
                    ? Colors.grey.withValues(alpha: 0.5)
                    : isSelected
                    ? const Color(0xFF10B981)
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                isDisabled ? '$title (Mobile only)' : title,
                style: TextStyle(
                  color: isDisabled ? Colors.grey : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected && !isDisabled)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
            else
              Icon(
                Icons.radio_button_off_rounded,
                color: isDisabled
                    ? Colors.grey.withValues(alpha: 0.5)
                    : Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMapSelection() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => GoogleMapsPicker(
          initialLat: _selectedLatitude,
          initialLng: _selectedLongitude,
          initialAddress: _selectedAddress.isNotEmpty ? _selectedAddress : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _selectedAddress = result['address'];
        _addressController.text = result['address'];
      });
    }
  }

  Widget _buildHandoverInstructions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Handover Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Location Section
          const Text(
            'Meet-up Location',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'Enter address or tap map to select',
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                    filled: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedAddress = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: FilledButton.tonal(
                  onPressed: _openMapSelection,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                  child: const Icon(Icons.map_outlined, size: 24),
                ),
              ),
            ],
          ),
          if (_selectedLatitude != null && _selectedLongitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Location selected: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ),
          const SizedBox(height: 20),

          // Message Section
          const Text(
            'Message for Seller',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Meet me at the Library foyer at 2 PM',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              fillColor: Colors.grey.withValues(alpha: 0.05),
              filled: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(
    BuildContext context,
    List<CartModel> checkoutItems,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _isProcessing || checkoutItems.isEmpty
                ? null
                : _handlePayment,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Pay & Confirm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
