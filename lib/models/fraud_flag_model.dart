import 'dart:convert';

import 'app_model.dart';
import 'json_utils.dart';

class FraudFlagModel implements AppModel {
  @override
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final int riskScore;
  final int listingsCreatedLast24Hours;
  final int repeatedMessageBurstCount;
  final List<String> reasons;
  final String? repeatedMessageSample;
  final DateTime? latestSignalAt;
  final List<SuspiciousListingSummary> suspiciousListings;

  const FraudFlagModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.riskScore,
    required this.listingsCreatedLast24Hours,
    required this.repeatedMessageBurstCount,
    required this.reasons,
    this.repeatedMessageSample,
    this.latestSignalAt,
    this.suspiciousListings = const [],
  });

  factory FraudFlagModel.fromMap(Map<String, dynamic> map) {
    return FraudFlagModel(
      id: JsonUtils.asString(map['id']) ?? '',
      userId: JsonUtils.asString(map['user_id']) ?? '',
      userName: JsonUtils.asString(map['user_name']) ?? '',
      userEmail: JsonUtils.asString(map['user_email']) ?? '',
      riskScore: JsonUtils.asInt(map['risk_score']) ?? 0,
      listingsCreatedLast24Hours:
          JsonUtils.asInt(map['listings_created_last_24_hours']) ?? 0,
      repeatedMessageBurstCount:
          JsonUtils.asInt(map['repeated_message_burst_count']) ?? 0,
      reasons: JsonUtils.asStringList(map['reasons']) ?? const [],
      repeatedMessageSample: JsonUtils.asString(map['repeated_message_sample']),
      latestSignalAt: JsonUtils.asDateTime(map['latest_signal_at']),
      suspiciousListings: ((map['suspicious_listings'] as List?) ?? const [])
          .map(
            (item) => SuspiciousListingSummary.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'risk_score': riskScore,
      'listings_created_last_24_hours': listingsCreatedLast24Hours,
      'repeated_message_burst_count': repeatedMessageBurstCount,
      'reasons': reasons,
      'repeated_message_sample': repeatedMessageSample,
      'latest_signal_at': latestSignalAt?.toIso8601String(),
      'suspicious_listings': suspiciousListings
          .map((listing) => listing.toMap())
          .toList(),
    };
  }

  factory FraudFlagModel.fromJson(String source) =>
      FraudFlagModel.fromMap(json.decode(source) as Map<String, dynamic>);

  String toJson() => json.encode(toMap());
}

class SuspiciousListingSummary {
  final String id;
  final String title;
  final DateTime? createdAt;

  const SuspiciousListingSummary({
    required this.id,
    required this.title,
    this.createdAt,
  });

  factory SuspiciousListingSummary.fromMap(Map<String, dynamic> map) {
    return SuspiciousListingSummary(
      id: JsonUtils.asString(map['id']) ?? '',
      title: JsonUtils.asString(map['title']) ?? '',
      createdAt: JsonUtils.asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
