import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../local/connectivity_service.dart';
import '../local/local_database_service.dart';

class ProductService {
  ProductService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const String _productImageBucket = ImageHelper.productImageBucket;
  final SupabaseClient _supabase;
  final LocalDatabaseService _localDatabase = LocalDatabaseService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;

  Future<List<ProductModel>> fetchProducts({String? status, String? sellerId}) async {
    final cachedProducts = await _localDatabase.getCachedProducts(
      status: status,
      sellerId: sellerId,
    );

    if (!await _connectivityService.isOnline()) {
      return cachedProducts;
    }

    try {
      var query = _supabase.from('products').select(
        '*, variations:product_variants(*, attributes:product_variant_attributes(*))',
      );

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      if (sellerId != null && sellerId.isNotEmpty) {
        query = query.eq('seller_id', sellerId);
      }

      final data = await query.order('created_at', ascending: false);

      final products = (data as List)
          .map(
            (item) => ProductModel.fromMap(
              _resolveProductImageFields(Map<String, dynamic>.from(item as Map)),
            ),
          )
          .toList();
      await _localDatabase.cacheProducts(products);
      return products;
    } on PostgrestException catch (e) {
      if (cachedProducts.isNotEmpty) {
        return cachedProducts;
      }
      throw Exception(e.message);
    } catch (e) {
      if (cachedProducts.isNotEmpty) {
        return cachedProducts;
      }
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<ProductModel> fetchProductById(String productId) async {
    final cachedProduct = await _localDatabase.getCachedProductById(productId);
    if (!await _connectivityService.isOnline()) {
      if (cachedProduct != null) {
        return cachedProduct;
      }
      throw Exception('Failed to fetch product details while offline.');
    }

    try {
      final data = await _supabase
          .from('products')
          .select(
            '*, variations:product_variants(*, attributes:product_variant_attributes(*))',
          )
          .eq('id', productId)
          .single();

      final product = ProductModel.fromMap(
        _resolveProductImageFields(Map<String, dynamic>.from(data)),
      );
      await _localDatabase.cacheProduct(product);
      return product;
    } on PostgrestException catch (e) {
      if (cachedProduct != null) {
        return cachedProduct;
      }
      throw Exception(e.message);
    } catch (e) {
      if (cachedProduct != null) {
        return cachedProduct;
      }
      throw Exception('Failed to fetch product details: $e');
    }
  }

  Future<List<ProductModel>> getCachedProducts({String? status, String? sellerId}) {
    return _localDatabase.getCachedProducts(status: status, sellerId: sellerId);
  }

  Future<List<ProductModel>> searchCachedProducts({
    required String query,
    String? status,
  }) => _localDatabase.searchCachedProducts(query: query, status: status);

  Future<List<String>> uploadImages(
    List<String> imagePaths,
    String userId,
  ) async {
    try {
      final imagePathsInBucket = <String>[];
      for (var index = 0; index < imagePaths.length; index++) {
        final path = imagePaths[index];
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${userId}_$index.webp';
        final webpBytes = await ImageHelper.convertFileToWebp(path);

        await _supabase.storage.from(_productImageBucket).uploadBinary(
          fileName,
          webpBytes,
          fileOptions: const FileOptions(contentType: ImageHelper.webpMimeType),
        );
        imagePathsInBucket.add(fileName);
      }
      return imagePathsInBucket;
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

  Future<String> createProduct(Map<String, dynamic> productData) async {
    try {
      final payload = Map<String, dynamic>.from(productData);
      if (!payload.containsKey('base_price') && payload.containsKey('price')) {
        payload['base_price'] = payload['price'];
      }
      if (!payload.containsKey('total_stock') &&
          payload.containsKey('available_quantity')) {
        payload['total_stock'] = payload['available_quantity'];
      }
      payload.remove('price');

      final response = await _supabase
          .from('products')
          .insert(payload)
          .select('id')
          .single();
      return response['id'] as String;
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  Future<void> createProductVariations(
    List<Map<String, dynamic>> variations,
  ) async {
    if (variations.isEmpty) {
      return;
    }

    try {
      final variantRows = variations
          .map(
            (variation) => <String, dynamic>{
              'product_id': variation['product_id'],
              'sku': variation['sku'],
              'price': variation['price'],
              'quantity':
                  variation['quantity'] ?? variation['available_quantity'] ?? 0,
            },
          )
          .toList();

      final insertedVariants = await _supabase
          .from('product_variants')
          .insert(variantRows)
          .select('id');

      final attributeRows = <Map<String, dynamic>>[];
      final insertedVariantList = List<Map<String, dynamic>>.from(
        insertedVariants as List,
      );
      for (var index = 0; index < variations.length; index++) {
        final variation = variations[index];
        final insertedVariantId = insertedVariantList[index]['id'] as String;
        final rawAttributes = variation['attributes'] as List? ??
            _legacyAttributesForVariation(variation);
        for (final rawAttribute in rawAttributes) {
          final attribute = Map<String, dynamic>.from(rawAttribute as Map);
          attributeRows.add({
            'variant_id': insertedVariantId,
            'attribute_name': attribute['attribute_name'],
            'attribute_value': attribute['attribute_value'],
          });
        }
      }

      if (attributeRows.isNotEmpty) {
        await _supabase.from('product_variant_attributes').insert(attributeRows);
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to create product variations: $e');
    }
  }

  List<Map<String, dynamic>> _legacyAttributesForVariation(
    Map<String, dynamic> variation,
  ) {
    final type = variation['variation_type']?.toString().trim() ?? '';
    final value = variation['variation_value']?.toString().trim() ?? '';
    if (type.isEmpty || value.isEmpty) {
      return const [];
    }

    return [
      {
        'attribute_name': type,
        'attribute_value': value,
      },
    ];
  }

  Future<void> createMeetupLocation(Map<String, dynamic> locationData) async {
    try {
      await _supabase.from('product_meetup_locations').insert(locationData);
    } catch (e) {
      throw Exception('Failed to create meetup location: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchMeetupLocation(String productId) async {
    try {
      final data = await _supabase
          .from('product_meetup_locations')
          .select()
          .eq('product_id', productId)
          .maybeSingle();
      return data != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      throw Exception('Failed to fetch meetup location: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> fetchMeetupLocations(
    List<String> productIds,
  ) async {
    final uniqueProductIds = productIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueProductIds.isEmpty) {
      return const {};
    }

    try {
      final data = await _supabase
          .from('product_meetup_locations')
          .select()
          .inFilter('product_id', uniqueProductIds);

      final locations = <String, Map<String, dynamic>>{};
      for (final row in (data as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final productId = map['product_id']?.toString();
        if (productId == null || productId.isEmpty || locations.containsKey(productId)) {
          continue;
        }
        locations[productId] = map;
      }
      return locations;
    } catch (e) {
      throw Exception('Failed to fetch meetup locations: $e');
    }
  }

  Future<void> updateMeetupLocation(String productId, Map<String, dynamic> locationData) async {
    try {
      // First check if a location exists for this product
      final existing = await fetchMeetupLocation(productId);
      if (existing != null) {
        await _supabase
            .from('product_meetup_locations')
            .update(locationData)
            .eq('product_id', productId);
      } else {
        await createMeetupLocation({
          ...locationData,
          'product_id': productId,
          'is_default': true,
        });
      }
    } catch (e) {
      throw Exception('Failed to update meetup location: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);
    } on PostgrestException catch (e) {
      // 23503 is the code for foreign key violation in PostgreSQL
      if (e.code == '23503') {
        await _supabase
            .from('products')
            .update({'status': 'inactive'}).eq('id', productId);
      } else {
        throw Exception(e.message);
      }
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> updateData) async {
    try {
      final data = {
        ...updateData,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (!data.containsKey('base_price') && data.containsKey('price')) {
        data['base_price'] = data['price'];
      }
      if (!data.containsKey('total_stock') &&
          data.containsKey('available_quantity')) {
        data['total_stock'] = data['available_quantity'];
      }
      data.remove('price');
      await _supabase.from('products').update(data).eq('id', productId);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Map<String, dynamic> _resolveProductImageFields(Map<String, dynamic> data) {
    final resolvedImages = ImageHelper.resolveProductImageUrls(data['image_urls']);
    final resolvedImageUrl =
        ImageHelper.resolveProductImageUrl(
          data['image_url']?.toString(),
          fallbackToDefault: false,
        ) ??
        (resolvedImages.isNotEmpty ? resolvedImages.first : null);

    return {
      ...data,
      'image_url': resolvedImageUrl,
      'image_urls': resolvedImages,
    };
  }
}
