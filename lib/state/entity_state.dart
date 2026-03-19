import 'package:flutter/foundation.dart';
import '../models/app_model.dart';

class EntityState<T extends AppModel> extends ChangeNotifier {
  final List<T> _items = [];
  bool _isLoading = false;
  String? _error;
  T? _selectedItem;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;
  T? get selectedItem => _selectedItem;
  bool get hasError => _error != null;
  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setItems(List<T> values) {
    _items
      ..clear()
      ..addAll(values);
    notifyListeners();
  }

  void addItem(T item) {
    _items.add(item);
    notifyListeners();
  }

  void addItems(List<T> values) {
    _items.addAll(values);
    notifyListeners();
  }

  void upsertItem(T item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index == -1) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
    notifyListeners();
  }

  void removeById(String id) {
    _items.removeWhere((e) => e.id == id);
    if (_selectedItem?.id == id) {
      _selectedItem = null;
    }
    notifyListeners();
  }

  T? getById(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void selectById(String id) {
    _selectedItem = getById(id);
    notifyListeners();
  }

  void setSelectedItem(T? item) {
    _selectedItem = item;
    notifyListeners();
  }

  void clearSelectedItem() {
    _selectedItem = null;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _selectedItem = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}