import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class PaymentModel implements AppModel {
  @override
  final String id;
  final String orderId;
  final String userId;
  final double amount;
  final String? paymentMethod;
  final String paymentStatus;
  final String? transactionId;
  final Map<String, dynamic>? gatewayResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    this.paymentMethod,
    this.paymentStatus = 'pending',
    this.transactionId,
    this.gatewayResponse,
    this.createdAt,
    this.updatedAt,
  });

  PaymentModel copyWith({
    String? id,
    String? orderId,
    String? userId,
    double? amount,
    String? paymentMethod,
    String? paymentStatus,
    String? transactionId,
    Map<String, dynamic>? gatewayResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transactionId: transactionId ?? this.transactionId,
      gatewayResponse: gatewayResponse ?? this.gatewayResponse,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderId: JsonUtils.asString(map['order_id']) ?? '',
      userId: JsonUtils.asString(map['user_id']) ?? '',
      amount: JsonUtils.asDouble(map['amount']) ?? 0,
      paymentMethod: JsonUtils.asString(map['payment_method']),
      paymentStatus: JsonUtils.asString(map['payment_status']) ?? 'pending',
      transactionId: JsonUtils.asString(map['transaction_id']),
      gatewayResponse: JsonUtils.asMap(map['gateway_response']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'transaction_id': transactionId,
      'gateway_response': gatewayResponse,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory PaymentModel.fromJson(String source) =>
      PaymentModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}