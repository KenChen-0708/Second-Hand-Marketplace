import 'package:flutter/material.dart';

import '../models/fraud_flag_model.dart';
import '../services/admin/admin_fraud_detection_service.dart';

class AdminFraudState extends ChangeNotifier {
  AdminFraudState({AdminFraudDetectionService? fraudDetectionService})
      : _fraudDetectionService =
            fraudDetectionService ?? AdminFraudDetectionService();

  final AdminFraudDetectionService _fraudDetectionService;

  List<FraudFlagModel> _flags = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastScannedAt;

  List<FraudFlagModel> get flags => _flags;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastScannedAt => _lastScannedAt;

  FraudFlagModel? flagForUser(String userId) {
    for (final flag in _flags) {
      if (flag.userId == userId) {
        return flag;
      }
    }
    return null;
  }

  Future<void> scanSuspiciousUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _flags = await _fraudDetectionService.scanAndFlagSuspiciousUsers();
      _lastScannedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
