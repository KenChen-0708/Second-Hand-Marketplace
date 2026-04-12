import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';

class FavoriteService {
  FavoriteService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<FavoriteModel?> fetchFavorite({
    required String userId,
    required String productId,
  }) async {
    try {
      final data = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return FavoriteModel.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to load wishlist status. Please try again.');
    }
  }

  Future<FavoriteModel> addFavorite({
    required String userId,
    required String productId,
  }) async {
    try {
      final inserted = await _supabase
          .from('favorites')
          .insert({
            'user_id': userId,
            'product_id': productId,
          })
          .select()
          .single();

      return FavoriteModel.fromMap(Map<String, dynamic>.from(inserted));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to add this item to your wishlist.');
    }
  }

  Future<void> removeFavorite({required String favoriteId}) async {
    try {
      await _supabase.from('favorites').delete().eq('id', favoriteId);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to remove this item from your wishlist.');
    }
  }

  Future<List<WishlistItemModel>> fetchWishlistItems({
    required String userId,
  }) async {
    try {
      final data = await _supabase
          .from('favorites')
          .select('id, user_id, product_id, created_at, products(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (data as List)
          .map(
            (item) => WishlistItemModel.fromMap(
              _resolveWishlistItem(Map<String, dynamic>.from(item as Map)),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to load your wishlist right now.');
    }
  }

  Map<String, dynamic> _resolveWishlistItem(Map<String, dynamic> item) {
    final product = item['products'];
    if (product is! Map) {
      return item;
    }

    final productMap = Map<String, dynamic>.from(product);
    final resolvedImages = ImageHelper.resolveProductImageUrls(
      productMap['image_urls'],
    );

    final resolvedImageUrl =
        ImageHelper.resolveProductImageUrl(
          productMap['image_url']?.toString(),
          fallbackToDefault: false,
        ) ??
        (resolvedImages.isNotEmpty ? resolvedImages.first : null);

    return {
      ...item,
      'products': {
        ...productMap,
        'image_url': resolvedImageUrl,
        'image_urls': resolvedImages,
      },
    };
  }
}
