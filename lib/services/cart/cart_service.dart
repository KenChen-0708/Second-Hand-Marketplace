import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';

class CartService {
  CartService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<CartModel>> fetchCartItems({required String userId}) async {
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

      return cartItems
          .where((item) => productsById.containsKey(item.productId))
          .map(
            (item) => CartModel(
              id: item.id,
              product: productsById[item.productId]!,
              quantity: item.quantity,
              addedAt: item.addedAt,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Unable to load your cart right now. ${e.message}');
    } catch (e) {
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

    try {
      final existing = await _supabase
          .from('cart_items')
          .select()
          .eq('user_id', userId)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existing != null) {
        final existingItem = CartItemModel.fromMap(
          Map<String, dynamic>.from(existing),
        );
        final updatedQuantity = existingItem.quantity + quantity;
        if (stockQuantity != null && updatedQuantity > stockQuantity) {
          throw Exception('Only $stockQuantity item(s) are currently available.');
        }

        final updated = await _supabase
            .from('cart_items')
            .update({
              'quantity': updatedQuantity,
            })
            .eq('id', existingItem.id)
            .select()
            .single();

        final updatedItem = CartItemModel.fromMap(
          Map<String, dynamic>.from(updated),
        );

        return CartActionResult(
          success: true,
          message: 'Item quantity updated in your cart.',
          item: CartModel(
            id: updatedItem.id,
            product: product,
            quantity: updatedItem.quantity,
            addedAt: updatedItem.addedAt,
          ),
        );
      }

      final inserted = await _supabase
          .from('cart_items')
          .insert({
            'user_id': userId,
            'product_id': product.id,
            'quantity': quantity,
          })
          .select()
          .single();

      final insertedItem = CartItemModel.fromMap(
        Map<String, dynamic>.from(inserted),
      );

      return CartActionResult(
        success: true,
        message: 'Item successfully added to your cart.',
        item: CartModel(
          id: insertedItem.id,
          product: product,
          quantity: insertedItem.quantity,
          addedAt: insertedItem.addedAt,
        ),
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
    required String cartItemId,
    required ProductModel product,
    required int quantity,
  }) async {
    if (cartItemId.isEmpty) {
      throw Exception('The selected cart item is invalid.');
    }

    try {
      if (quantity <= 0) {
        await _supabase.from('cart_items').delete().eq('id', cartItemId);
        return null;
      }

      final stockQuantity = product.stockQuantity;
      if (stockQuantity != null && quantity > stockQuantity) {
        throw Exception('Only $stockQuantity item(s) are currently available.');
      }

      final updated = await _supabase
          .from('cart_items')
          .update({
            'quantity': quantity,
          })
          .eq('id', cartItemId)
          .select()
          .single();

      final updatedItem = CartItemModel.fromMap(
        Map<String, dynamic>.from(updated),
      );

      return CartModel(
        id: updatedItem.id,
        product: product,
        quantity: updatedItem.quantity,
        addedAt: updatedItem.addedAt,
      );
    } on PostgrestException catch (e) {
      throw Exception('Unable to update your cart right now. ${e.message}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unable to update your cart right now. Please try again.');
    }
  }

  Future<void> removeCartItem({required String cartItemId}) async {
    if (cartItemId.isEmpty) {
      throw Exception('The selected cart item is invalid.');
    }

    try {
      await _supabase.from('cart_items').delete().eq('id', cartItemId);
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

    try {
      await _supabase.from('cart_items').delete().eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Unable to clear your cart right now. ${e.message}');
    } catch (e) {
      throw Exception('Unable to clear your cart right now. Please try again.');
    }
  }

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
