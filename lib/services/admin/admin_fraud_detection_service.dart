import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/fraud_flag_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../notification/notification_service.dart';

class AdminFraudDetectionService {
  AdminFraudDetectionService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client,
        _notificationService =
            NotificationService(client: client ?? Supabase.instance.client);

  static const int listingBurstThreshold = 5;
  static const int repeatedMessageThreshold = 4;
  static const Duration detectionWindow = Duration(hours: 24);

  final SupabaseClient _supabase;
  final NotificationService _notificationService;

  Future<List<FraudFlagModel>> scanAndFlagSuspiciousUsers() async {
    final users = await _fetchUsers();
    if (users.isEmpty) {
      return const [];
    }

    final products = await _fetchRecentProducts();
    final chatMessages = await _fetchRecentChatMessages();
    final flags = _buildFlags(users: users, products: products, chatMessages: chatMessages);
    await _persistAutomaticFlags(flags);
    return flags;
  }

  Future<List<UserModel>> _fetchUsers() async {
    final response = await _supabase
        .from('users')
        .select()
        .neq('role', 'admin');
    return (response as List)
        .map((row) => UserModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<ProductModel>> _fetchRecentProducts() async {
    final since = DateTime.now().toUtc().subtract(detectionWindow).toIso8601String();
    final response = await _supabase
        .from('products')
        .select('id,title,seller_id,status,created_at')
        .gte('created_at', since);

    return (response as List)
        .map((row) => ProductModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchRecentChatMessages() async {
    final since = DateTime.now().toUtc().subtract(detectionWindow).toIso8601String();
    final response = await _supabase
        .from('chat_messages')
        .select('id,sender_id,message_text,created_at,is_image')
        .gte('created_at', since)
        .eq('is_image', false);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  List<FraudFlagModel> _buildFlags({
    required List<UserModel> users,
    required List<ProductModel> products,
    required List<Map<String, dynamic>> chatMessages,
  }) {
    final productsBySeller = <String, List<ProductModel>>{};
    for (final product in products) {
      productsBySeller.putIfAbsent(product.sellerId, () => []).add(product);
    }

    final repeatedMessageSignals = _buildRepeatedMessageSignals(chatMessages);
    final flags = <FraudFlagModel>[];

    for (final user in users) {
      final reasons = <String>[];
      final sellerProducts = [...(productsBySeller[user.id] ?? const <ProductModel>[])];
      sellerProducts.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) {
          return a.title.compareTo(b.title);
        }
        if (aTime == null) {
          return 1;
        }
        if (bTime == null) {
          return -1;
        }
        return bTime.compareTo(aTime);
      });
      final repeatedSignal = repeatedMessageSignals[user.id];
      var score = 0;
      DateTime? latestSignalAt;

      if (sellerProducts.length >= listingBurstThreshold) {
        reasons.add(
          '${sellerProducts.length} listings created within ${detectionWindow.inHours} hours',
        );
        score += min(50, sellerProducts.length * 8);
        for (final product in sellerProducts) {
          if (_isLater(product.createdAt, latestSignalAt)) {
            latestSignalAt = product.createdAt;
          }
        }
      }

      if (repeatedSignal != null &&
          repeatedSignal.repeatCount >= repeatedMessageThreshold) {
        reasons.add(
          'Repeated the same message ${repeatedSignal.repeatCount} times in ${detectionWindow.inHours} hours',
        );
        score += min(50, repeatedSignal.repeatCount * 10);
        if (_isLater(repeatedSignal.latestAt, latestSignalAt)) {
          latestSignalAt = repeatedSignal.latestAt;
        }
      }

      if (reasons.isEmpty) {
        continue;
      }

      flags.add(
        FraudFlagModel(
          id: user.id,
          userId: user.id,
          userName: user.name,
          userEmail: user.email,
          riskScore: score.clamp(0, 100).toInt(),
          listingsCreatedLast24Hours: sellerProducts.length,
          repeatedMessageBurstCount: repeatedSignal?.repeatCount ?? 0,
          reasons: reasons,
          repeatedMessageSample: repeatedSignal?.messageSample,
          latestSignalAt: latestSignalAt,
          suspiciousListings: sellerProducts
              .map(
                (product) => SuspiciousListingSummary(
                  id: product.id,
                  title: product.title,
                  createdAt: product.createdAt,
                ),
              )
              .toList(),
        ),
      );
    }

    flags.sort((a, b) {
      final scoreCompare = b.riskScore.compareTo(a.riskScore);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final aTime = a.latestSignalAt;
      final bTime = b.latestSignalAt;
      if (aTime == null && bTime == null) {
        return a.userName.compareTo(b.userName);
      }
      if (aTime == null) {
        return 1;
      }
      if (bTime == null) {
        return -1;
      }
      return bTime.compareTo(aTime);
    });

    return flags;
  }

  Map<String, _RepeatedMessageSignal> _buildRepeatedMessageSignals(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (final row in rows) {
      final senderId = row['sender_id']?.toString();
      final messageText = _normalizeMessage(row['message_text']?.toString());
      if (senderId == null || senderId.isEmpty || messageText == null) {
        continue;
      }
      grouped
          .putIfAbsent(senderId, () => {})
          .putIfAbsent(messageText, () => [])
          .add(row);
    }

    final result = <String, _RepeatedMessageSignal>{};
    grouped.forEach((senderId, messages) {
      _RepeatedMessageSignal? strongest;
      messages.forEach((normalizedMessage, occurrences) {
        if (occurrences.length < repeatedMessageThreshold) {
          return;
        }
        DateTime? latestAt;
        for (final row in occurrences) {
          final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
          if (_isLater(createdAt, latestAt)) {
            latestAt = createdAt;
          }
        }
        final signal = _RepeatedMessageSignal(
          repeatCount: occurrences.length,
          messageSample: normalizedMessage,
          latestAt: latestAt,
        );
        if (strongest == null || signal.repeatCount > strongest!.repeatCount) {
          strongest = signal;
        }
      });
      if (strongest != null) {
        result[senderId] = strongest!;
      }
    });

    return result;
  }

  Future<void> _persistAutomaticFlags(List<FraudFlagModel> flags) async {
    if (flags.isEmpty) {
      return;
    }

    final adminRows = await _supabase
        .from('users')
        .select('id')
        .eq('role', 'admin');
    final adminIds = (adminRows as List)
        .map((row) => (row as Map)['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (adminIds.isEmpty) {
      return;
    }
    final actorAdminId = adminIds.first;

    for (final flag in flags) {
      final signature = _flagSignature(flag);
      final existing = await _supabase
          .from('admin_logs')
          .select('id')
          .eq('action', 'fraud_flagged')
          .eq('entity_type', 'user')
          .eq('entity_id', flag.userId)
          .contains('details', {'signature': signature})
          .limit(1);

      if ((existing as List).isNotEmpty) {
        continue;
      }

      await _supabase.from('admin_logs').insert({
        'admin_id': actorAdminId,
        'action': 'fraud_flagged',
        'entity_type': 'user',
        'entity_id': flag.userId,
        'details': {
          ...flag.toMap(),
          'signature': signature,
          'flagged_automatically': true,
        },
      });

      final title = 'Suspicious user detected';
      final message =
          '${flag.userName} triggered ${flag.reasons.join(' and ')}.';
      for (final adminId in adminIds) {
        await _notificationService.createNotification(
          userId: adminId,
          title: title,
          message: message,
          type: 'system',
          sendPush: false,
        );
      }
    }
  }

  String _flagSignature(FraudFlagModel flag) {
    return [
      flag.userId,
      flag.listingsCreatedLast24Hours,
      flag.repeatedMessageBurstCount,
      flag.repeatedMessageSample ?? '',
    ].join('|');
  }

  bool _isLater(DateTime? value, DateTime? other) {
    if (value == null) {
      return false;
    }
    if (other == null) {
      return true;
    }
    return value.isAfter(other);
  }

  String? _normalizeMessage(String? value) {
    final trimmed = value?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty || trimmed.length < 8) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _RepeatedMessageSignal {
  const _RepeatedMessageSignal({
    required this.repeatCount,
    required this.messageSample,
    required this.latestAt,
  });

  final int repeatCount;
  final String messageSample;
  final DateTime? latestAt;
}
