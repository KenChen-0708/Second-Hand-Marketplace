import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class OrderModel implements AppModel {
  @override
  final String id;
  final String orderNumber;
  final String buyerId;
  final String sellerId;
  final String productId;
  final int quantity;
  final double totalPrice;
  final String status;
  final String? paymentMethod;
  final String paymentStatus;
  final String? handoverLocation;
  final DateTime? handoverDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    this.quantity = 1,
    required this.totalPrice,
    this.status = 'Pending',
    this.paymentMethod,
    this.paymentStatus = 'Pending',
    this.handoverLocation,
    this.handoverDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? buyerId,
    String? sellerId,
    String? productId,
    int? quantity,
    double? totalPrice,
    String? status,
    String? paymentMethod,
    String? paymentStatus,
    String? handoverLocation,
    DateTime? handoverDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      handoverLocation: handoverLocation ?? this.handoverLocation,
      handoverDate: handoverDate ?? this.handoverDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderNumber: JsonUtils.asString(map['order_number']) ?? '',
      buyerId: JsonUtils.asString(map['buyer_id']) ?? '',
      sellerId: JsonUtils.asString(map['seller_id']) ?? '',
      productId: JsonUtils.asString(map['product_id']) ?? '',
      quantity: JsonUtils.asInt(map['quantity']) ?? 1,
      totalPrice: JsonUtils.asDouble(map['total_price']) ?? 0,
      status: JsonUtils.asString(map['status']) ?? 'Pending',
      paymentMethod: JsonUtils.asString(map['payment_method']),
      paymentStatus: JsonUtils.asString(map['payment_status']) ?? 'Pending',
      handoverLocation: JsonUtils.asString(map['handover_location']),
      handoverDate: JsonUtils.asDateTime(map['handover_date']),
      notes: JsonUtils.asString(map['notes']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'product_id': productId,
      'quantity': quantity,
      'total_price': totalPrice,
      'status': status,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'handover_location': handoverLocation,
      'handover_date': handoverDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory OrderModel.fromJson(String source) =>
      OrderModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}