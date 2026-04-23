import 'dart:convert';

import 'app_model.dart';
import 'json_utils.dart';

enum SupportChatRole { assistant, user }

class SupportChatMessageModel implements AppModel {
  const SupportChatMessageModel({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.suggestedReplies = const [],
    this.isFallback = false,
  });

  @override
  final String id;
  final SupportChatRole role;
  final String text;
  final DateTime createdAt;
  final List<String> suggestedReplies;
  final bool isFallback;

  bool get isUser => role == SupportChatRole.user;
  bool get isAssistant => role == SupportChatRole.assistant;

  SupportChatMessageModel copyWith({
    String? id,
    SupportChatRole? role,
    String? text,
    DateTime? createdAt,
    List<String>? suggestedReplies,
    bool? isFallback,
  }) {
    return SupportChatMessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      suggestedReplies: suggestedReplies ?? this.suggestedReplies,
      isFallback: isFallback ?? this.isFallback,
    );
  }

  factory SupportChatMessageModel.fromMap(Map<String, dynamic> map) {
    final rawRole = JsonUtils.asString(map['role']) ?? 'assistant';

    return SupportChatMessageModel(
      id: JsonUtils.asString(map['id']) ?? '',
      role: rawRole == 'user' ? SupportChatRole.user : SupportChatRole.assistant,
      text: JsonUtils.asString(map['text']) ?? '',
      createdAt: JsonUtils.asDateTime(map['created_at']) ?? DateTime.now(),
      suggestedReplies: JsonUtils.asStringList(map['suggested_replies']) ?? const [],
      isFallback: JsonUtils.asBool(map['is_fallback']) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role == SupportChatRole.user ? 'user' : 'assistant',
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'suggested_replies': suggestedReplies,
      'is_fallback': isFallback,
    };
  }

  factory SupportChatMessageModel.fromJson(String source) =>
      SupportChatMessageModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}
