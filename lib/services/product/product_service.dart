import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';

class ProductService {
  ProductService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<ProductModel>> fetchProducts({String? status}) async {
    try {
      final data = status != null && status.isNotEmpty
          ? await _supabase
                .from('products')
                .select()
                .eq('status', status)
                .order('created_at')
          : await _supabase.from('products').select().order('created_at');

      return (data as List)
          .map(
            (item) => ProductModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<ProductModel> fetchProductById(String productId) async {
    try {
      final data = await _supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      return ProductModel.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch product details: $e');
    }
  }
}
