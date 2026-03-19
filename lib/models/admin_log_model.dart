import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class AdminLogModel implements AppModel {
  @override
  final String id;
  final String adminId;
  final String action;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? details;
  final DateTime? createdAt;

  const AdminLogModel({
    required this.id,
    required this.adminId,
    required this.action,
    this.entityType,
    this.entityId,
    this.details,
    this.createdAt,
  });

  AdminLogModel copyWith({
    String? id,
    String? adminId,
    String? action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? details,
    DateTime? createdAt,
  }) {
    return AdminLogModel(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AdminLogModel.fromMap(Map<String, dynamic> map) {
    return AdminLogModel(
      id: JsonUtils.asString(map['id']) ?? '',
      adminId: JsonUtils.asString(map['admin_id']) ?? '',
      action: JsonUtils.asString(map['action']) ?? '',
      entityType: JsonUtils.asString(map['entity_type']),
      entityId: JsonUtils.asString(map['entity_id']),
      details: JsonUtils.asMap(map['details']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'admin_id': adminId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory AdminLogModel.fromJson(String source) =>
      AdminLogModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}