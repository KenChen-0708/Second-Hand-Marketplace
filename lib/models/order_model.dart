import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';
import 'order_item_model.dart';

class OrderModel implements AppModel {
  @override
  final String id;
  final String orderNumber;
  final String buyerId;
  final double totalPrice;
  final String status;
  final String paymentStatus;
  final String? handoverLocation;
  final DateTime? handoverDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderItemModel> orderItems;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.buyerId,
    required this.totalPrice,
    this.status = 'Pending',
    this.paymentStatus = 'Pending',
    this.handoverLocation,
    this.handoverDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.orderItems = const [],
  });

  String? get primaryProductId =>
      orderItems.isEmpty ? null : orderItems.first.productId;

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? buyerId,
    double? totalPrice,
    String? status,
    String? paymentStatus,
    String? handoverLocation,
    DateTime? handoverDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderItemModel>? orderItems,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      buyerId: buyerId ?? this.buyerId,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      handoverLocation: handoverLocation ?? this.handoverLocation,
      handoverDate: handoverDate ?? this.handoverDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderItems: orderItems ?? this.orderItems,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawOrderItems = map['order_items'];
    return OrderModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderNumber: JsonUtils.asString(map['order_number']) ?? '',
      buyerId: JsonUtils.asString(map['buyer_id']) ?? '',
      totalPrice: JsonUtils.asDouble(map['total_price']) ?? 0,
      status: JsonUtils.asString(map['status']) ?? 'Pending',
      paymentStatus: JsonUtils.asString(map['payment_status']) ?? 'Pending',
      handoverLocation: JsonUtils.asString(map['handover_location']),
      handoverDate: JsonUtils.asDateTime(map['handover_date']),
      notes: JsonUtils.asString(map['notes']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
      orderItems: rawOrderItems is List
          ? rawOrderItems
                .map(
                  (item) => OrderItemModel.fromMap(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'buyer_id': buyerId,
      'total_price': totalPrice,
      'status': status,
      'payment_status': paymentStatus,
      'handover_location': handoverLocation,
      'handover_date': handoverDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'order_items': orderItems.map((item) => item.toMap()).toList(),
    };
  }

  factory OrderModel.fromJson(String source) =>
      OrderModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
