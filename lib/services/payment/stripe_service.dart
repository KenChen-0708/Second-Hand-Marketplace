import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/payment_model.dart';

class StripeService {
  StripeService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  static const String publishableKey =
      'pk_test_51SSdhpL3TTFqZeEi4TfS0go9Kuzf50Z2ARl66lIETSElJo2RGjTkpwXmUZZafDmrMbkKAFnWzOH7v1J9JVH1Xlgw00gueZneix';
  static const String _secretKey =
      'sk_test_51SSdhpL3TTFqZeEiC8Zq2GlP6vX1oU0BVr1Il5xr0T5OXKXkewj27TGIxs0AvwzSfcHlY2znCsIlexDHk9gbJOXE00vbXRgf2n';

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  final SupabaseClient _supabase;

  Future<StripePaymentResult> payWithCard({
    required double amount,
    String currency = 'myr',
  }) async {
    if (!isSupportedPlatform) {
      throw Exception(
        'Card payment is only available on Android and iOS devices.',
      );
    }

    if (amount <= 0) {
      throw Exception(
        'Card payment requires a total amount greater than RM 0.00.',
      );
    }

    try {
      final paymentIntent = await _createPaymentIntent(
        amount: amount,
        currency: currency,
      );
      final clientSecret = paymentIntent['client_secret']?.toString();
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Stripe did not return a valid client secret.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Campus Marketplace',
          style: ThemeMode.light,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return StripePaymentResult(
        paymentIntentId: paymentIntent['id']?.toString() ?? '',
        clientSecret: clientSecret,
        response: paymentIntent,
      );
    } on StripeException catch (e) {
      final message = e.error.localizedMessage ?? 'Card payment was cancelled.';
      throw Exception(message);
    } catch (e) {
      throw Exception('Unable to process card payment. ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<PaymentModel> createPaymentRecord({
    required String orderId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required String paymentStatus,
    String? transactionId,
    Map<String, dynamic>? gatewayResponse,
  }) async {
    try {
      final inserted = await _supabase
          .from('payments')
          .insert({
            'order_id': orderId,
            'user_id': userId,
            'amount': amount,
            'payment_method': paymentMethod,
            'payment_status': paymentStatus,
            'transaction_id': transactionId,
            'gateway_response': gatewayResponse,
          })
          .select()
          .single();

      return PaymentModel.fromMap(Map<String, dynamic>.from(inserted));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to save payment details.');
    }
  }

  Future<Map<String, dynamic>> _createPaymentIntent({
    required double amount,
    required String currency,
  }) async {
    final amountInSmallestUnit = (amount * 100).round();
    if (amountInSmallestUnit <= 0) {
      throw Exception('Stripe payment amount must be greater than 0.');
    }
    final response = await http.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'amount': '$amountInSmallestUnit',
        'currency': currency,
        'payment_method_types[]': 'card',
      },
    );

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          body['error'] is Map<String, dynamic>
              ? (body['error']['message']?.toString() ?? 'Stripe request failed.')
              : 'Stripe request failed.';
      throw Exception(message);
    }

    return body;
  }
}

class StripePaymentResult {
  const StripePaymentResult({
    required this.paymentIntentId,
    required this.clientSecret,
    required this.response,
  });

  final String paymentIntentId;
  final String clientSecret;
  final Map<String, dynamic> response;
}
