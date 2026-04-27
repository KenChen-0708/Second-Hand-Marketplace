import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class UserModel implements AppModel {
  @override
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final bool pushEnabled; // Added this
  final bool isOnline;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? country;
  final String? bio;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.role = 'user',
    this.isActive = true,
    this.pushEnabled = false, // Default to false
    this.isOnline = false,
    this.phoneNumber,
    this.address,
    this.city,
    this.postalCode,
    this.country,
    this.bio,
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? role,
    bool? isActive,
    bool? pushEnabled,
    bool? isOnline,
    String? phoneNumber,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? bio,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      isOnline: isOnline ?? this.isOnline,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: JsonUtils.asString(map['id']) ?? '',
      email: JsonUtils.asString(map['email']) ?? '',
      name: JsonUtils.asString(map['name']) ?? '',
      avatarUrl: JsonUtils.asString(map['avatar_url']),
      role: JsonUtils.asString(map['role']) ?? 'user',
      isActive: JsonUtils.asBool(map['is_active']) ?? true,
      pushEnabled: JsonUtils.asBool(map['push_enabled']) ?? false,
      isOnline: JsonUtils.asBool(map['is_online']) ?? false,
      phoneNumber: JsonUtils.asString(map['phone_number']),
      address: JsonUtils.asString(map['address']),
      city: JsonUtils.asString(map['city']),
      postalCode: JsonUtils.asString(map['postal_code']),
      country: JsonUtils.asString(map['country']),
      bio: JsonUtils.asString(map['bio']),
      lastSeenAt: JsonUtils.asDateTime(map['last_seen_at']),
      createdAt: JsonUtils.asDateTime(map['created_at']),
      updatedAt: JsonUtils.asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'role': role,
      'is_active': isActive,
      'push_enabled': pushEnabled,
      'is_online': isOnline,
      'phone_number': phoneNumber,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'country': country,
      'bio': bio,
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
