import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../local/connectivity_service.dart';
import '../local/local_database_service.dart';

class CartService {
  CartService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final LocalDatabaseService _localDatabase = LocalDatabaseService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;

  Future<List<CartModel>> fetchCartItems({required String userId}) async {
    final cachedItems = await _localDatabase.getCachedCartItems(userId);
    if (!await _connectivityService.isOnline()) {
      return cachedItems;
    }

    try {
      final cartData = await _supabase
          .from('cart_items')
          .select()
          .eq('user_id', userId)
          .order('added_at');

      final cartItems = (cartData as List)
          .map(
            (item) =>
                CartItemModel.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

      if (cartItems.isEmpty) {
        await _localDatabase.clearCartLocally(userId, markForSync: false);
        return const [];
      }

      final productIds = cartItems.map((item) => item.productId).toList();
      final productData = await _supabase
          .from('products')
          .select('*, variations:product_variations(*)')
          .inFilter('id', productIds);

      final productsById = <String, ProductModel>{};
      for (final product in (productData as List)) {
        final model = ProductModel.fromMap(
          _resolveProductMap(Map<String, dynamic>.from(product as Map)),
        );
        productsById[model.id] = model;
      }

      final items = cartItems
          .where((item) => productsById.containsKey(item.productId))
          .map(
            (item) => CartModel(
              id: _localCartId(userId, item.productId),
              product: productsById[item.productId]!,
              quantity: item.quantity,
              addedAt: item.addedAt,
            ),
          )
          .toList();
      await _localDatabase.cacheProducts(productsById.values.toList());
      await _localDatabase.replaceCartItems(userId, items);
      return items;
    } on PostgrestException catch (e) {
      if (cachedItems.isNotEmpty) {
        return cachedItems;
      }
      throw Exception('Unable to load your cart right now. ${e.message}');
    } catch (e) {
      if (cachedItems.isNotEmpty) {
        return cachedItems;
      }
      throw Exception('Unable to load your cart right now. Please try again.');
    }
  }

  Future<CartActionResult> addToCart({
    required String userId,
    required ProductModel product,
    int quantity = 1,
  }) async {
    if (userId.isEmpty || product.id.isEmpty || quantity <= 0) {
      throw Exception('Please choose a valid item and quantity.');
    }
    if (product.isSoldOut) {
      throw Exception('This product is sold out.');
    }
    final stockQuantity = product.stockQuantity;
    if (stockQuantity != null && quantity > stockQuantity) {
      throw Exception('Only $stockQuantity item(s) are currently available.');
    }

    final cachedItems = await _localDatabase.getCachedCartItems(userId);
    final existing = cachedItems.cast<CartModel?>().firstWhere(
      (item) => item?.product.id == product.id,
      orElse: () => null,
    );
    final updatedQuantity = (existing?.quantity ?? 0) + quantity;
    if (stockQuantity != null && updatedQuantity > stockQuantity) {
      throw Exception('Only $stockQuantity item(s) are currently available.');
    }

    final localItem = CartModel(
      id: _localCartId(userId, product.id),
      product: product,
      quantity: updatedQuantity,
      addedAt: existing?.addedAt ?? DateTime.now(),
    );
    await _localDatabase.cacheProduct(product);
    await _localDatabase.upsertCartItem(
      userId: userId,
      product: product,
      quantity: updatedQuantity,
      addedAt: localItem.addedAt,
      syncStatus: 'pending',
    );

    if (!await _connectivityService.isOnline()) {
      return CartActionResult(
        success: true,
        message: existing == null
            ? 'Item saved to your cart for offline use.'
            : 'Item quantity updated locally and will sync when online.',
        item: localItem,
      );
    }

    try {
      await _supabase.from('cart_items').upsert({
        'user_id': userId,
        'product_id': product.id,
        'quantity': updatedQuantity,
      }, onConflict: 'user_id,product_id');
      await _localDatabase.upsertCartItem(
        userId: userId,
        product: product,
        quantity: updatedQuantity,
        addedAt: localItem.addedAt,
        syncStatus: 'synced',
      );
      return CartActionResult(
        success: true,
        message: existing == null
            ? 'Item successfully added to your cart.'
            : 'Item quantity updated in your cart.',
        item: localItem,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to add item to cart, please try again. ${e.message}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to add item to cart, please try again.');
    }
  }

  Future<CartModel?> updateCartItemQuantity({
    required String userId,
    required String productId,
    required ProductModel product,
    required int quantity,
  }) async {
    if (productId.isEmpty) {
      throw Exception('The selected cart item is invalid.');
    }

    final stockQuantity = product.stockQuantity;
    if (stockQuantity != null && quantity > stockQuantity) {
      throw Exception('Only $stockQuantity item(s) are currently available.');
    }

    if (quantity <= 0) {
      await removeCartItem(userId: userId, productId: productId);
      return null;
    }

    await _localDatabase.cacheProduct(product);
    await _localDatabase.upsertCartItem(
      userId: userId,
      product: product,
      quantity: quantity,
      syncStatus: 'pending',
    );

    final updatedItem = CartModel(
      id: _localCartId(userId, productId),
      product: product,
      quantity: quantity,
      addedAt: DateTime.now(),
    );

    if (!await _connectivityService.isOnline()) {
      return updatedItem;
    }

    try {
      await _supabase.from('cart_items').upsert({
        'user_id': userId,
        'product_id': productId,
        'quantity': quantity,
      }, onConflict: 'user_id,product_id');
      await _localDatabase.upsertCartItem(
        userId: userId,
        product: product,
        quantity: quantity,
        addedAt: updatedItem.addedAt,
        syncStatus: 'synced',
      );
      return updatedItem;
    } on PostgrestException catch (e) {
      throw Exception('Unable to update your cart right now. ${e.message}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unable to update your cart right now. Please try again.');
    }
  }

  Future<void> removeCartItem({
    required String userId,
    required String productId,
  }) async {
    if (productId.isEmpty) {
      throw Exception('The selected cart item is invalid.');
    }

    await _localDatabase.markCartItemDeleted(userId: userId, productId: productId);
    if (!await _connectivityService.isOnline()) {
      return;
    }

    try {
      await _supabase
          .from('cart_items')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
      await _localDatabase.deleteCartItemPermanently(
        userId: userId,
        productId: productId,
      );
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to remove this item from your cart. ${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to remove this item from your cart. Please try again.',
      );
    }
  }

  Future<void> clearCart({required String userId}) async {
    if (userId.isEmpty) {
      throw Exception('A logged-in user is required to manage the cart.');
    }

    final isOnline = await _connectivityService.isOnline();
    await _localDatabase.clearCartLocally(userId, markForSync: isOnline);
    if (!isOnline) {
      return;
    }

    try {
      await _supabase.from('cart_items').delete().eq('user_id', userId);
      await _localDatabase.clearCartLocally(userId, markForSync: false);
    } on PostgrestException catch (e) {
      throw Exception('Unable to clear your cart right now. ${e.message}');
    } catch (e) {
      throw Exception('Unable to clear your cart right now. Please try again.');
    }
  }

  Future<void> syncCart(String userId) async {
    if (!await _connectivityService.isOnline()) {
      return;
    }

    final pendingRows = await _localDatabase.getPendingCartRows(userId);
    for (final row in pendingRows) {
      final productId = row['product_id'] as String;
      if ((row['is_deleted'] as int) == 1 ||
          row['sync_status'] == 'pending_delete') {
        await _supabase
            .from('cart_items')
            .delete()
            .eq('user_id', userId)
            .eq('product_id', productId);
        await _localDatabase.deleteCartItemPermanently(
          userId: userId,
          productId: productId,
        );
        continue;
      }

      await _supabase.from('cart_items').upsert({
        'user_id': userId,
        'product_id': productId,
        'quantity': row['quantity'],
      }, onConflict: 'user_id,product_id');
      await _localDatabase.upsertCartItem(
        userId: userId,
        product: ProductModel.fromJson(row['product_data'] as String),
        quantity: row['quantity'] as int,
        addedAt: row['added_at'] == null
            ? null
            : DateTime.tryParse(row['added_at'] as String),
        syncStatus: 'synced',
      );
    }
  }

  String _localCartId(String userId, String productId) => '${userId}_$productId';

  Map<String, dynamic> _resolveProductMap(Map<String, dynamic> productMap) {
    final resolvedImages = ImageHelper.resolveProductImageUrls(
      productMap['image_urls'],
    );
    final resolvedImageUrl =
        ImageHelper.resolveProductImageUrl(
          productMap['image_url']?.toString(),
          fallbackToDefault: false,
        ) ??
        (resolvedImages.isNotEmpty
            ? resolvedImages.first
            : ImageHelper.defaultProductImageUrl);

    return {
      ...productMap,
      'image_url': resolvedImageUrl,
      'image_urls': resolvedImages,
    };
  }
}
