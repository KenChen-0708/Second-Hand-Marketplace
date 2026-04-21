import 'package:supabase_flutter/supabase_flutter.dart';
import 'entity_state.dart';
import '../models/models.dart';

class CategoryState extends EntityState<CategoryModel> {
  final _supabase = Supabase.instance.client;
  List<SubcategoryModel> _subcategories = [];
  List<SubcategoryModel> get subcategories => _subcategories;

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
      // Try fetching with new column 'sort_priority', fallback to name
      try {
        final response = await _supabase
            .from('subcategories')
            .select()
            .eq('category_id', categoryId)
            .order('sort_priority');

        _subcategories = (response as List)
            .map((m) => SubcategoryModel.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        final response = await _supabase
            .from('subcategories')
            .select()
            .eq('category_id', categoryId)
            .order('name');

        _subcategories = (response as List)
            .map((m) => SubcategoryModel.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }
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
      final response = await _supabase
          .from('subcategories')
          .insert({
            'category_id': categoryId,
            'name': name,
            'is_enabled': true,
            'sort_priority': _subcategories.length,
          })
          .select()
          .single();
      _subcategories.add(SubcategoryModel.fromMap(Map<String, dynamic>.from(response)));
      notifyListeners();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> deleteSubcategory(String id) async {
    try {
      await _supabase.from('subcategories').delete().eq('id', id);
      _subcategories.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
}
