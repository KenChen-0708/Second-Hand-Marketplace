import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class SubcategoryModel implements AppModel {
  @override
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final bool isEnabled;
  final int sortPriority;
  final DateTime? createdAt;

  const SubcategoryModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    this.isEnabled = true,
    this.sortPriority = 0,
    this.createdAt,
  });

  SubcategoryModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? description,
    bool? isEnabled,
    int? sortPriority,
    DateTime? createdAt,
  }) {
    return SubcategoryModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      sortPriority: sortPriority ?? this.sortPriority,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SubcategoryModel.fromMap(Map<String, dynamic> map) {
    return SubcategoryModel(
      id: JsonUtils.asString(map['id']) ?? '',
      categoryId: JsonUtils.asString(map['category_id']) ?? '',
      name: JsonUtils.asString(map['name']) ?? '',
      description: JsonUtils.asString(map['description']),
      isEnabled: map['is_enabled'] ?? true,
      sortPriority: JsonUtils.asInt(map['sort_priority']) ?? 0,
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'is_enabled': isEnabled,
      'sort_priority': sortPriority,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory SubcategoryModel.fromJson(String source) =>
      SubcategoryModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
