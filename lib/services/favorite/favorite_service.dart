import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../local/connectivity_service.dart';
import '../local/local_database_service.dart';
import '../product/product_service.dart';

class FavoriteService {
  FavoriteService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final LocalDatabaseService _localDatabase = LocalDatabaseService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  final ProductService _productService = ProductService();

  Future<FavoriteModel?> fetchFavorite({
    required String userId,
    required String productId,
  }) async {
    final cachedWishlist = await _localDatabase.getCachedWishlistItems(userId);
    final cachedMatch = cachedWishlist
        .map((item) => item.favorite)
        .cast<FavoriteModel?>()
        .firstWhere(
          (item) => item?.productId == productId,
          orElse: () => null,
        );

    if (!await _connectivityService.isOnline()) {
      return cachedMatch;
    }

    try {
      final data = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (data == null) {
        await _localDatabase.markWishlistItemDeleted(
          userId: userId,
          productId: productId,
        );
        return null;
      }

      return FavoriteModel.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      if (cachedMatch != null) {
        return cachedMatch;
      }
      throw Exception(e.message);
    } catch (e) {
      if (cachedMatch != null) {
        return cachedMatch;
      }
      throw Exception('Unable to load wishlist status. Please try again.');
    }
  }

  Future<FavoriteModel> addFavorite({
    required String userId,
    required String productId,
  }) async {
    final product = await _productService.fetchProductById(productId);
    await _localDatabase.upsertWishlistItem(
      userId: userId,
      product: product,
      syncStatus: 'pending',
    );

    if (!await _connectivityService.isOnline()) {
      return FavoriteModel(
        id: '${userId}_$productId',
        userId: userId,
        productId: productId,
        createdAt: DateTime.now(),
      );
    }

    try {
      final inserted = await _supabase
          .from('favorites')
          .upsert({
            'user_id': userId,
            'product_id': productId,
          }, onConflict: 'user_id,product_id')
          .select()
          .single();

      final favorite = FavoriteModel.fromMap(Map<String, dynamic>.from(inserted));
      await _localDatabase.upsertWishlistItem(
        userId: userId,
        product: product,
        createdAt: favorite.createdAt,
        syncStatus: 'synced',
      );
      return favorite;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to add this item to your wishlist.');
    }
  }

  Future<void> removeFavorite({
    required String userId,
    required String productId,
  }) async {
    await _localDatabase.markWishlistItemDeleted(
      userId: userId,
      productId: productId,
    );

    if (!await _connectivityService.isOnline()) {
      return;
    }

    try {
      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
      await _localDatabase.deleteWishlistItemPermanently(
        userId: userId,
        productId: productId,
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to remove this item from your wishlist.');
    }
  }

  Future<List<WishlistItemModel>> fetchWishlistItems({
    required String userId,
  }) async {
    final cachedItems = await _localDatabase.getCachedWishlistItems(userId);
    if (!await _connectivityService.isOnline()) {
      return cachedItems;
    }

    try {
      final data = await _supabase
          .from('favorites')
          .select('id, user_id, product_id, created_at, products(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final wishlistItems = (data as List)
          .map(
            (item) => WishlistItemModel.fromMap(
              _resolveWishlistItem(Map<String, dynamic>.from(item as Map)),
            ),
          )
          .toList();
      await _localDatabase.replaceWishlistItems(userId, wishlistItems);
      await _localDatabase.cacheProducts(
        wishlistItems.map((item) => item.product).toList(),
      );
      return wishlistItems;
    } on PostgrestException catch (e) {
      if (cachedItems.isNotEmpty) {
        return cachedItems;
      }
      throw Exception(e.message);
    } catch (e) {
      if (cachedItems.isNotEmpty) {
        return cachedItems;
      }
      throw Exception('Unable to load your wishlist right now.');
    }
  }

  Future<void> syncWishlist(String userId) async {
    if (!await _connectivityService.isOnline()) {
      return;
    }

    final pendingRows = await _localDatabase.getPendingWishlistRows(userId);
    for (final row in pendingRows) {
      final productId = row['product_id'] as String;
      if ((row['is_deleted'] as int) == 1 ||
          row['sync_status'] == 'pending_delete') {
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', productId);
        await _localDatabase.deleteWishlistItemPermanently(
          userId: userId,
          productId: productId,
        );
        continue;
      }

      await _supabase.from('favorites').upsert({
        'user_id': userId,
        'product_id': productId,
      }, onConflict: 'user_id,product_id');
      await _localDatabase.upsertWishlistItem(
        userId: userId,
        product: ProductModel.fromJson(row['product_data'] as String),
        createdAt: row['created_at'] == null
            ? null
            : DateTime.tryParse(row['created_at'] as String),
        syncStatus: 'synced',
      );
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
