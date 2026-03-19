import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class DisputeModel implements AppModel {
  @override
  final String id;
  final String orderId;
  final String reporterId;
  final String accusedId;
  final String reason;
  final String description;
  final String status;
  final String? adminNotes;
  final String? resolutionNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  const DisputeModel({
    required this.id,
    required this.orderId,
    required this.reporterId,
    required this.accusedId,
    required this.reason,
    required this.description,
    this.status = 'open',
    this.adminNotes,
    this.resolutionNotes,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  DisputeModel copyWith({
    String? id,
    String? orderId,
    String? reporterId,
    String? accusedId,
    String? reason,
    String? description,
    String? status,
    String? adminNotes,
    String? resolutionNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return DisputeModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      reporterId: reporterId ?? this.reporterId,
      accusedId: accusedId ?? this.accusedId,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  factory DisputeModel.fromMap(Map<String, dynamic> map) {
    return DisputeModel(
      id: JsonUtils.asString(map['id']) ?? '',
      orderId: JsonUtils.asString(map['order_id']) ?? '',
      reporterId: JsonUtils.asString(map['reporter_id']) ?? '',
      accusedId: JsonUtils.asString(map['accused_id']) ?? '',
      reason: JsonUtils.asString(map['reason']) ?? '',
      description: JsonUtils.asString(map['description']) ?? '',
      status: JsonUtils.asString(map['status']) ?? 'open',
      adminNotes: JsonUtils.asString(map['admin_notes']),
      resolutionNotes: JsonUtils.asString(map['resolution_notes']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
      resolvedAt: JsonUtils.asDateTime(map['resolved_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'reporter_id': reporterId,
      'accused_id': accusedId,
      'reason': reason,
      'description': description,
      'status': status,
      'admin_notes': adminNotes,
      'resolution_notes': resolutionNotes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  factory DisputeModel.fromJson(String source) =>
      DisputeModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}