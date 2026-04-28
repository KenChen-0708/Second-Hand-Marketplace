import 'package:supabase_flutter/supabase_flutter.dart';
import 'entity_state.dart';
import '../models/models.dart';

enum CategorySortMode {
  custom,
  nameAsc,
  nameDesc,
  countAsc,
  countDesc,
}

class CategoryState extends EntityState<CategoryModel> {
  final _supabase = Supabase.instance.client;
  final Map<String, List<SubcategoryModel>> _subcategoriesByCategory = {};
  List<SubcategoryModel> get subcategories =>
      _subcategoriesByCategory.values.expand((list) => list).toList();
  List<SubcategoryModel> subcategoriesForCategory(String categoryId) =>
      List<SubcategoryModel>.unmodifiable(
        _subcategoriesByCategory[categoryId] ?? const <SubcategoryModel>[],
      );

  CategorySortMode _sortMode = CategorySortMode.custom;
  CategorySortMode get sortMode => _sortMode;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSortMode(CategorySortMode mode) {
    _sortMode = mode;
    _applySortAndFilter();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applySortAndFilter();
  }

  List<CategoryModel> get filteredItems {
    List<CategoryModel> list = List.from(items);
    
    // Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) => item.name.toLowerCase().contains(_searchQuery)).toList();
    }

    // Sort
    switch (_sortMode) {
      case CategorySortMode.custom:
        list.sort((a, b) => a.sortPriority.compareTo(b.sortPriority));
        break;
      case CategorySortMode.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case CategorySortMode.nameDesc:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case CategorySortMode.countAsc:
        list.sort((a, b) => a.productCount.compareTo(b.productCount));
        break;
      case CategorySortMode.countDesc:
        list.sort((a, b) => b.productCount.compareTo(a.productCount));
        break;
    }
    
    return list;
  }

  void _applySortAndFilter() {
    notifyListeners();
  }

  Future<void> fetchAllCategories() async {
    setLoading(true);
    setError(null);
    try {
      // 1. Try full fetch with counts and sorting by new column 'sort_priority'
      try {
        final response = await _supabase
            .from('categories')
            .select('*, products(count)')
            .order('sort_priority');

        final categories = (response as List).map((m) {
          final countList = m['products'] as List?;
          final count = (countList != null && countList.isNotEmpty)
              ? countList[0]['count'] as int
              : 0;
          return CategoryModel.fromMap({...m, 'product_count': count});
        }).toList();

        setItems(categories);
        return;
      } catch (_) {
        // 2. Fallback to basic name-only fetch if new columns don't exist yet
        final response = await _supabase.from('categories').select().order('name');
        final categories = (response as List)
            .map((m) => CategoryModel.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        setItems(categories);
      }
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  Future<void> toggleCategoryStatus(String id, bool currentStatus) async {
    try {
      // Optimistically update local state
      final existing = getById(id);
      if (existing != null) {
        upsertItem(existing.copyWith(isEnabled: !currentStatus));
      }

      // 2. Update database using new column name 'is_enabled'
      try {
        await _supabase
            .from('categories')
            .update({'is_enabled': !currentStatus})
            .eq('id', id);
      } on PostgrestException catch (e) {
        // Revert local state if DB update fails
        if (existing != null) {
          upsertItem(existing);
        }
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchSubcategories(String categoryId) async {
    try {
      late final List<SubcategoryModel> subcategories;

      // Try fetching with new column 'sort_priority', fallback to name
      try {
        final response = await _supabase
            .from('subcategories')
            .select()
            .eq('category_id', categoryId)
            .order('sort_priority');

        subcategories = (response as List)
            .map((m) => SubcategoryModel.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        final response = await _supabase
            .from('subcategories')
            .select()
            .eq('category_id', categoryId)
            .order('name');

        subcategories = (response as List)
            .map((m) => SubcategoryModel.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }

      _subcategoriesByCategory[categoryId] = subcategories;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<void> addCategory(String name) async {
    try {
      int nextOrder = 0;
      try {
        final maxOrderResp = await _supabase
            .from('categories')
            .select('sort_priority')
            .order('sort_priority', ascending: false)
            .limit(1)
            .maybeSingle();
        nextOrder = (maxOrderResp?['sort_priority'] ?? -1) + 1;
      } catch (_) {}

      final response = await _supabase
          .from('categories')
          .insert({
        'name': name,
        'sort_priority': nextOrder,
        'is_enabled': true,
      })
          .select()
          .single();

      addItem(CategoryModel.fromMap(Map<String, dynamic>.from(response)));
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> updateCategory(String id, String newName) async {
    try {
      await _supabase.from('categories').update({'name': newName}).eq('id', id);
      final existing = getById(id);
      if (existing != null) upsertItem(existing.copyWith(name: newName));
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      removeById(id);
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> updateCategoryOrder(List<CategoryModel> reorderedList) async {
    // If we are in custom sort mode, we update the database
    if (_sortMode != CategorySortMode.custom) return;

    setItems(reorderedList);
    try {
      final updates = reorderedList.asMap().entries.map((entry) {
        return _supabase
            .from('categories')
            .update({'sort_priority': entry.key})
            .eq('id', entry.value.id);
      }).toList();
      await Future.wait(updates);
    } catch (_) {
      // Silently fail if column missing
    }
  }

  Future<void> addSubcategory(String categoryId, String name) async {
    try {
      final currentSubcategories = _subcategoriesByCategory[categoryId] ?? const [];
      final payload = <String, dynamic>{
        'category_id': categoryId,
        'name': name,
        'is_enabled': true,
        'sort_priority': currentSubcategories.length,
      };

      try {
        await _supabase.from('subcategories').insert(payload);
      } on PostgrestException catch (e) {
        if (_isDuplicateSubcategoryIdError(e)) {
          await _insertSubcategoryWithAllocatedId(payload);
        } else {
          await _supabase.from('subcategories').insert({
            'category_id': categoryId,
            'name': name,
          });
        }
      } catch (_) {
        await _supabase.from('subcategories').insert({
          'category_id': categoryId,
          'name': name,
        });
      }

      await fetchSubcategories(categoryId);
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  bool _isDuplicateSubcategoryIdError(PostgrestException error) {
    final details = error.details?.toString() ?? '';
    return error.code == '23505' &&
        (error.message.contains('subcategories_pkey') ||
            details.contains('Key (id)='));
  }

  Future<void> _insertSubcategoryWithAllocatedId(
    Map<String, dynamic> payload,
  ) async {
    var nextNumber = await _fetchNextSubcategoryNumber();
    for (var attempt = 0; attempt < 10; attempt++) {
      final retryPayload = Map<String, dynamic>.from(payload)
        ..['id'] = _formatSubcategoryId(nextNumber + attempt);
      try {
        await _supabase.from('subcategories').insert(retryPayload);
        return;
      } on PostgrestException catch (e) {
        if (!_isDuplicateSubcategoryIdError(e)) {
          rethrow;
        }
      }
    }

    throw Exception('Unable to allocate a unique subcategory ID.');
  }

  Future<int> _fetchNextSubcategoryNumber() async {
    final rows = await _supabase
        .from('subcategories')
        .select('id')
        .like('id', 'SCAT%');

    var highest = 0;
    for (final row in rows as List) {
      final id = (row as Map)['id']?.toString();
      if (id == null || !id.startsWith('SCAT')) {
        continue;
      }

      final number = int.tryParse(id.substring(4));
      if (number != null && number > highest) {
        highest = number;
      }
    }

    return highest + 1;
  }

  String _formatSubcategoryId(int number) {
    return 'SCAT${number.toString().padLeft(4, '0')}';
  }

  Future<void> deleteSubcategory(String categoryId, String id) async {
    try {
      await _supabase.from('subcategories').delete().eq('id', id);
      final existing = List<SubcategoryModel>.from(
        _subcategoriesByCategory[categoryId] ?? const <SubcategoryModel>[],
      );
      existing.removeWhere((s) => s.id == id);
      _subcategoriesByCategory[categoryId] = existing;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
}
