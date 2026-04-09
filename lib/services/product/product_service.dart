import 'dart:io';
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
            (item) =>
                ProductModel.fromMap(Map<String, dynamic>.from(item as Map)),
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

  Future<List<String>> uploadImages(
    List<String> imagePaths,
    String userId,
  ) async {
    try {
      List<String> imageUrls = [];
      for (String path in imagePaths) {
        final file = File(path);
        final fileExt = path.split('.').last;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$userId.$fileExt';

        await _supabase.storage.from('product_images').upload(fileName, file);
        final publicUrl = _supabase.storage
            .from('product_images')
            .getPublicUrl(fileName);
        imageUrls.add(publicUrl);
      }
      return imageUrls;
    } catch (e) {
      throw Exception('Failed to upload images: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final data = await _supabase.from('categories').select().order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubcategories(String categoryId) async {
    try {
      final data = await _supabase
          .from('subcategories')
          .select()
          .eq('category_id', categoryId)
          .order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Failed to fetch subcategories: $e');
    }
  }

  Future<String> getOrCreateCategory(String categoryName) async {
    try {
      final catResp = await _supabase
          .from('categories')
          .select('id')
          .ilike('name', categoryName)
          .maybeSingle();

      if (catResp != null) {
        return catResp['id'] as String;
      } else {
        final newCat = await _supabase
            .from('categories')
            .insert({'name': categoryName})
            .select('id')
            .single();
        return newCat['id'] as String;
      }
    } catch (e) {
      throw Exception('Failed to handle category: $e');
    }
  }

  Future<String> getOrCreateSubcategory(String categoryId, String subcategoryName) async {
    try {
      final subResp = await _supabase
          .from('subcategories')
          .select('id')
          .eq('category_id', categoryId)
          .ilike('name', subcategoryName)
          .maybeSingle();

      if (subResp != null) {
        return subResp['id'] as String;
      } else {
        final newSub = await _supabase
            .from('subcategories')
            .insert({'category_id': categoryId, 'name': subcategoryName})
            .select('id')
            .single();
        return newSub['id'] as String;
      }
    } catch (e) {
      throw Exception('Failed to handle subcategory: $e');
    }
  }

  Future<void> createProduct(Map<String, dynamic> productData) async {
    try {
      await _supabase.from('products').insert(productData);
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }
}
