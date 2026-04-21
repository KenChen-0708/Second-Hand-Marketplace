import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/local/connectivity_service.dart';
import '../../services/payment/stripe_service.dart';
import '../../services/product/product_service.dart';
import '../../shared/utils/currency_helper.dart';
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
  static const String _meetUpOption = 'meet_up';
  static const String _deliveryOption = 'delivery';
  static const double _officialDeliveryFee = 5.0;

  String _selectedPaymentMethod = 'Credit/Debit Card';
  String _selectedHandoverOption = _meetUpOption;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isProcessing = false;
  late final List<CartModel> _checkoutItemsSnapshot;
  final ProductService _productService = ProductService();

  // Location fields
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';
  bool _isLoadingMeetupLocations = false;
  String? _meetupLocationError;
  Map<String, Map<String, dynamic>> _meetupLocationsByProductId = const {};
  bool _isCheckingConnectivity = true;
  bool _isCheckoutOffline = false;

  @override
  void initState() {
    super.initState();
    _checkoutItemsSnapshot = List<CartModel>.from(
      widget.session?.items ?? context.read<CartState>().items,
    );
    _selectedHandoverOption = _defaultHandoverOption;
    if (!StripeService.isSupportedPlatform) {
      _selectedPaymentMethod = 'Campus Wallet';
    }
    _checkConnectivityAndLoad();
  }

  Future<void> _checkConnectivityAndLoad() async {
    final isOnline = await ConnectivityService.instance.isOnline();
    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckoutOffline = !isOnline;
      _isCheckingConnectivity = false;
    });

    if (isOnline) {
      await _loadMeetupLocations();
    }
  }

  Future<void> _loadMeetupLocations() async {
    final productIds = _checkoutItems.map((item) => item.product.id).toSet().toList();
    if (productIds.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMeetupLocations = true;
      _meetupLocationError = null;
    });

    try {
      final locations = await _productService.fetchMeetupLocations(productIds);
      if (!mounted) {
        return;
      }

      setState(() {
        _meetupLocationsByProductId = locations;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _meetupLocationError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMeetupLocations = false;
        });
      }
    }
  }

  Future<void> _handlePayment() async {
    if (!await ConnectivityService.instance.isOnline()) {
      if (!mounted) {
        return;
      }
      setState(() => _isCheckoutOffline = true);
      return;
    }

    if (!_hasProvidedLocation) {
      SnackbarHelper.showInfo(
        context,
        _selectedHandoverOption == _meetUpOption
            ? 'Meet-up location is required.'
            : 'Delivery address is required.',
      );
      return;
    }

    if (!_hasCompatibleHandoverOption) {
      SnackbarHelper.showInfo(
        context,
        'Please check out these items separately.',
      );
      return;
    }

    if (_selectedHandoverOption == _meetUpOption && !_meetUpAvailable) {
      SnackbarHelper.showInfo(
        context,
        'Meet-up is not available for these items.',
      );
      return;
    }

    if (!_availableHandoverOptions.contains(_selectedHandoverOption)) {
      SnackbarHelper.showInfo(
        context,
        'This handover option is not available.',
      );
      return;
    }

    if (_isCardPayment && _grandTotal <= 0) {
      SnackbarHelper.showInfo(
        context,
        'Card payment is unavailable for this total.',
      );
      return;
    }

    setState(() => _isProcessing = true);

    final cartState = context.read<CartState>();
    final orderState = context.read<OrderState>();
    final paymentState = context.read<PaymentState>();
    final checkoutItems = _checkoutItems;
    StripePaymentResult? stripeResult;

    try {
      if (widget.session?.isBuyNow != true) {
        await cartState.syncWithRemote();
      }

      if (_isCardPayment) {
        stripeResult = await paymentState.payWithCard(_grandTotal);
      }

      final orders = await orderState.checkoutItems(
        items: checkoutItems,
        cartState: widget.session?.clearCartAfterSuccess == true
            ? cartState
            : (widget.session == null ? cartState : null),
        clearCartAfterSuccess:
            widget.session?.clearCartAfterSuccess ?? widget.session == null,
        handoverLocation: _resolvedHandoverLocation,
        notes: _buildCheckoutNotes(),
        additionalFee: _deliveryFee,
        status: 'pending',
        paymentStatus: 'paid',
      );

      if (!mounted) {
        return;
      }

      final createdOrder = orders.isNotEmpty ? orders.first : null;
      if (_isCardPayment && createdOrder != null) {
        await paymentState.createPaymentRecord(
          orderId: createdOrder.id,
          amount: _grandTotal,
          paymentMethod: _paymentMethodCode,
          paymentStatus: 'paid',
          transactionId: stripeResult?.paymentIntentId,
          gatewayResponse: stripeResult?.response,
        );
      }

      if (widget.session != null &&
          widget.session!.items.isNotEmpty &&
          widget.session!.clearCartAfterSuccess != true &&
          widget.session!.isBuyNow != true) {
        await cartState.removeMultipleFromCart(widget.session!.items);
      }

      final router = GoRouter.of(context);
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      router.go('/home');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await showDialog(
        context: rootNavigator.context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
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
                      Navigator.of(dialogContext).pop();
                      router.push(
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

      SnackbarHelper.showError(context, 'Unable to place order. Please try again.');
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

    if (_isCheckingConnectivity) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isCheckoutOffline) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 72),
                const SizedBox(height: 16),
                Text(
                  'No internet connection',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again. Checkout needs internet so we can confirm payment, stock, and order details.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _checkConnectivityAndLoad,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

  double get _itemsSubtotal =>
      _checkoutItems.fold<double>(0, (sum, item) => sum + item.totalPrice);

  Set<String> get _availableHandoverOptions {
    final options = <String>{};
    if (_meetUpAvailable) {
      options.add(_meetUpOption);
    }
    if (_deliveryAvailable) {
      options.add(_deliveryOption);
    }
    return options;
  }

  bool get _meetUpAvailable => _checkoutItems.isNotEmpty &&
      _checkoutItems.every(
        (item) => item.product.tradePreference.contains('face_to_face'),
      );

  bool get _deliveryAvailable => _checkoutItems.isNotEmpty &&
      _checkoutItems.every(
        (item) => item.product.tradePreference.any(
          (preference) =>
              preference == 'delivery_official' ||
              preference == 'delivery_self',
        ),
      );

  bool get _hasCompatibleHandoverOption => _availableHandoverOptions.isNotEmpty;

  String get _defaultHandoverOption {
    if (_meetUpAvailable) {
      return _meetUpOption;
    }
    if (_deliveryAvailable) {
      return _deliveryOption;
    }
    return _meetUpOption;
  }

  double get _deliveryFee =>
      _selectedHandoverOption == _deliveryOption &&
              _checkoutItems.any(
                (item) => item.product.tradePreference.contains('delivery_official'),
              )
          ? _officialDeliveryFee
          : 0;

  double get _grandTotal => _itemsSubtotal + _deliveryFee;

  List<CartModel> get _meetupItems =>
      _checkoutItems
          .where(
            (item) => item.product.tradePreference.contains('face_to_face'),
          )
          .toList();

  bool get _hasAllSellerMeetupLocations =>
      _meetupItems.isNotEmpty &&
      _meetupItems.every(
        (item) => _meetupLocationsByProductId.containsKey(item.product.id),
      );

  bool get _hasProvidedLocation =>
      _selectedHandoverOption == _meetUpOption
          ? !_isLoadingMeetupLocations && _hasAllSellerMeetupLocations
          : _selectedAddress.trim().isNotEmpty;

  String? get _resolvedHandoverLocation {
    if (_selectedHandoverOption == _meetUpOption) {
      if (!_hasAllSellerMeetupLocations) {
        return null;
      }
      return _sellerMeetupAddress.isEmpty ? null : _sellerMeetupAddress;
    }

    final address = _selectedAddress.trim();
    return address.isEmpty ? null : address;
  }

  bool get _isCardPayment => _selectedPaymentMethod == 'Credit/Debit Card';

  bool get _canUseCardPayment =>
      StripeService.isSupportedPlatform && _grandTotal > 0;

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

  String get _locationLabel =>
      _selectedHandoverOption == _meetUpOption
          ? 'Meet-up Location'
          : 'Delivery Address';

  String get _locationHint =>
      _selectedHandoverOption == _meetUpOption
          ? 'Set by the seller'
          : 'Enter delivery address or tap map to select';

  String get _selectedHandoverLabel {
    switch (_selectedHandoverOption) {
      case _meetUpOption:
        return 'Meet Up';
      case _deliveryOption:
        return 'Delivery';
      default:
        return 'Meet Up';
    }
  }

  String get _selectedDeliveryHelperText {
    final hasOfficialDeliveryItem = _checkoutItems.any(
      (item) => item.product.tradePreference.contains('delivery_official'),
    );
    if (hasOfficialDeliveryItem) {
      return 'Delivery includes the seller\'s configured delivery method and any official delivery fee.';
    }
    return 'The seller will arrange delivery directly with you.';
  }

  String? get _incompatibleHandoverMessage {
    if (_hasCompatibleHandoverOption) {
      return null;
    }

    return 'These items do not share a common buyer-facing handover option. Please checkout them separately.';
  }

  String get _sellerMeetupAddress {
    final lines = <String>[];
    final seenProductIds = <String>{};

    for (final item in _meetupItems) {
      if (!seenProductIds.add(item.product.id)) {
        continue;
      }

      final location = _meetupLocationsByProductId[item.product.id];
      if (location == null) {
        continue;
      }

      final locationName = (location['location_name']?.toString() ?? '').trim();
      final address = (location['address']?.toString() ?? '').trim();
      final primaryLabel = locationName.isNotEmpty ? locationName : address;
      final summary = address.isNotEmpty && address != locationName
          ? '$primaryLabel, $address'
          : primaryLabel;
      if (summary.isNotEmpty && !lines.contains(summary)) {
        lines.add(summary);
      }
    }

    return lines.join('\n');
  }

  List<_HandoverOptionData> get _handoverOptionItems {
    final options = <_HandoverOptionData>[];
    if (_meetUpAvailable) {
      options.add(
        const _HandoverOptionData(
          label: 'Meet Up',
          value: _meetUpOption,
          icon: Icons.handshake_outlined,
        ),
      );
    }
    if (_deliveryAvailable) {
      options.add(
        const _HandoverOptionData(
          label: 'Delivery',
          value: _deliveryOption,
          icon: Icons.local_shipping_outlined,
        ),
      );
    }
    return options;
  }

  String? _buildCheckoutNotes() {
    final buyerMessage = _messageController.text.trim();
    final noteParts = <String>[
      'Handover option: $_selectedHandoverLabel',
      if (buyerMessage.isNotEmpty) 'Buyer message: $buyerMessage',
    ];

    return noteParts.isEmpty ? null : noteParts.join('\n');
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
                          if (cartItem.variantLabel != null)
                            Text(
                              cartItem.variantLabel!,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            '${CurrencyHelper.formatRM(cartItem.unitPrice)} x ${cartItem.quantity}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Subtotal: ${CurrencyHelper.formatRM(cartItem.totalPrice)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
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
                'Items Subtotal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                CurrencyHelper.formatRM(_itemsSubtotal),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (_deliveryFee > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Delivery Fee',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  CurrencyHelper.formatRM(_deliveryFee),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
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
                CurrencyHelper.formatRM(_grandTotal),
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
    final isDisabled = isCardOption && !_canUseCardPayment;
    final disabledLabel = !StripeService.isSupportedPlatform
        ? '$title (Mobile only)'
        : '$title (Min RM 0.01)';
    final disabledMessage = !StripeService.isSupportedPlatform
        ? 'Card payment is only available on mobile.'
        : 'Card payment is unavailable for this total.';

    return InkWell(
      onTap: isDisabled
          ? () => SnackbarHelper.showInfo(
              context,
              disabledMessage,
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
                isDisabled ? disabledLabel : title,
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
          Text(
            _locationLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedHandoverOption == _meetUpOption) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.store_mall_directory_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seller-set location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (_isLoadingMeetupLocations) ...[
                          const SizedBox(height: 8),
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ] else if (_meetupLocationError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _meetupLocationError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else if (_sellerMeetupAddress.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _sellerMeetupAddress,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text(
                            'No seller meetup location is available for the selected item.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _locationHint,
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
                  width: 64,
                  height: 64,
                  child: FilledButton.tonal(
                    onPressed: _openMapSelection,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: const Color(0xFF166534),
                    ),
                    child: const Center(
                      child: Icon(Icons.map_outlined, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_selectedHandoverOption == _deliveryOption &&
              _addressController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Delivery Address',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _addressController.text.trim(),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedHandoverOption == _deliveryOption &&
              _selectedLatitude != null &&
              _selectedLongitude != null)
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
          const SizedBox(height: 20),
          const Text(
            'Handover Option',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _handoverOptionItems
                .map(
                  (option) => _buildDeliveryOptionChip(
                    label: option.label,
                    value: option.value,
                    icon: option.icon,
                  ),
                )
                .toList(),
          ),
          if (_incompatibleHandoverMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _incompatibleHandoverMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (_selectedHandoverOption == _deliveryOption &&
              _deliveryFee > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Official delivery adds ${CurrencyHelper.formatRM(_officialDeliveryFee)} to this checkout.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (_selectedHandoverOption == _deliveryOption)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _selectedDeliveryHelperText,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOptionChip({
    required String label,
    required String value,
    required IconData icon,
    bool enabled = true,
  }) {
    final isSelected = _selectedHandoverOption == value;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: enabled
            ? (isSelected ? Colors.white : Theme.of(context).colorScheme.primary)
            : Colors.grey,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: enabled
          ? (_) => setState(() => _selectedHandoverOption = value)
          : null,
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: enabled
            ? (isSelected ? Colors.white : null)
            : Colors.grey,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: enabled
            ? Theme.of(context).colorScheme.outlineVariant
            : Colors.grey.shade300,
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
            onPressed: _isProcessing ||
                    checkoutItems.isEmpty ||
                    !_hasProvidedLocation ||
                    !_hasCompatibleHandoverOption
                ? null
                : _handlePayment,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
              child: Text(
              !_hasCompatibleHandoverOption
                  ? 'Separate Items to Checkout'
                  : _selectedHandoverOption == _meetUpOption &&
                          _isLoadingMeetupLocations
                  ? 'Loading Meetup Location...'
                  : _selectedHandoverOption == _meetUpOption &&
                          !_hasProvidedLocation
                  ? 'Seller Meetup Location Required'
                  : _hasProvidedLocation
                  ? 'Place Order'
                  : 'Add Location to Continue',
              style: const TextStyle(
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

class _HandoverOptionData {
  const _HandoverOptionData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
