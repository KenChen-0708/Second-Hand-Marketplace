import 'dart:convert';
import 'app_model.dart';
import 'json_utils.dart';

class ChatMessageModel implements AppModel {
  @override
  final String id;
  final String conversationId;
  final String senderId;
  final String messageText;
  final bool isImage;
  final String? imageUrl;
  final bool isRead;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageText,
    this.isImage = false,
    this.imageUrl,
    this.isRead = false,
    this.createdAt,
  });

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? messageText,
    bool? isImage,
    String? imageUrl,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      messageText: messageText ?? this.messageText,
      isImage: isImage ?? this.isImage,
      imageUrl: imageUrl ?? this.imageUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: JsonUtils.asString(map['id']) ?? '',
      conversationId: JsonUtils.asString(map['conversation_id']) ?? '',
      senderId: JsonUtils.asString(map['sender_id']) ?? '',
      messageText: JsonUtils.asString(map['message_text']) ?? '',
      isImage: JsonUtils.asBool(map['is_image']) ?? false,
      imageUrl: JsonUtils.asString(map['image_url']),
      isRead: JsonUtils.asBool(map['is_read']) ?? false,
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_text': messageText,
      'is_image': isImage,
      'image_url': imageUrl,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory ChatMessageModel.fromJson(String source) =>
      ChatMessageModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}