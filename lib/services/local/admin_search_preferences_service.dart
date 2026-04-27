import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class AdminSearchPreferenceKeys {
  AdminSearchPreferenceKeys._();

  static const userManagement = 'admin_search_user_management';
  static const categoryManagement = 'admin_search_category_management';
  static const listingModeration = 'admin_search_listing_moderation';
  static const orderManagement = 'admin_search_order_management';
}

class AdminSearchPreferencesService {
  AdminSearchPreferencesService._();

  static final AdminSearchPreferencesService instance =
      AdminSearchPreferencesService._();

  static const int _historyLimit = 8;

  final StreamController<String?> _clearCurrentSearchController =
      StreamController<String?>.broadcast();
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    final cached = _prefs;
    if (cached != null) {
      return cached;
    }

    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    return prefs;
  }

  Future<List<String>> readSearchHistory(String key) async {
    final prefs = await _preferences;
    return _sanitizeHistory(prefs.getStringList(_historyKey(key)));
  }

  Future<String> readCurrentSearchQuery(String key) async {
    final prefs = await _preferences;
    return prefs.getString(_currentSearchKey(key))?.trim() ?? '';
  }

  Future<void> writeCurrentSearchQuery(String key, String value) async {
    final prefs = await _preferences;
    final normalizedValue = value.trim();

    if (normalizedValue.isEmpty) {
      await prefs.remove(_currentSearchKey(key));
      return;
    }

    await prefs.setString(_currentSearchKey(key), normalizedValue);
  }

  Future<List<String>> addSearchHistoryEntry(String key, String value) async {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      return readSearchHistory(key);
    }

    final prefs = await _preferences;
    final currentHistory = _sanitizeHistory(
      prefs.getStringList(_historyKey(key)),
    );

    final nextHistory = <String>[
      normalizedValue,
      ...currentHistory.where(
        (entry) => entry.toLowerCase() != normalizedValue.toLowerCase(),
      ),
    ];

    if (nextHistory.length > _historyLimit) {
      nextHistory.removeRange(_historyLimit, nextHistory.length);
    }

    await prefs.setStringList(_historyKey(key), nextHistory);
    return nextHistory;
  }

  Future<List<String>> removeSearchHistoryEntry(
    String key,
    String value,
  ) async {
    final prefs = await _preferences;
    final nextHistory = _sanitizeHistory(
      prefs.getStringList(_historyKey(key)),
    ).where((entry) => entry.toLowerCase() != value.trim().toLowerCase()).toList();

    if (nextHistory.isEmpty) {
      await prefs.remove(_historyKey(key));
      return const [];
    }

    await prefs.setStringList(_historyKey(key), nextHistory);
    return nextHistory;
  }

  Future<void> clearSearchHistory(String key) async {
    final prefs = await _preferences;
    await prefs.remove(_historyKey(key));
  }

  Stream<String?> get clearCurrentSearchStream =>
      _clearCurrentSearchController.stream;

  void requestClearCurrentSearch([String? key]) {
    _clearCurrentSearchController.add(key);
  }

  List<String> _sanitizeHistory(List<String>? history) {
    if (history == null || history.isEmpty) {
      return const [];
    }

    final unique = <String>[];
    final seen = <String>{};

    for (final entry in history) {
      final normalized = entry.trim();
      if (normalized.isEmpty) {
        continue;
      }

      final caseInsensitiveKey = normalized.toLowerCase();
      if (seen.add(caseInsensitiveKey)) {
        unique.add(normalized);
      }
    }

    return unique;
  }

  String _historyKey(String key) => '${key}_history';

  String _currentSearchKey(String key) => '${key}_current';
}
