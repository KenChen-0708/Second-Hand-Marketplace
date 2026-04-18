import 'dart:async';

import '../models/models.dart';
import '../services/auth/auth_service.dart';
import '../services/favorite/favorite_service.dart';
import '../services/local/connectivity_service.dart';
import 'entity_state.dart';

class FavoriteState extends EntityState<FavoriteModel> {
  FavoriteState({
    FavoriteService? favoriteService,
    AuthService? authService,
  }) : _favoriteService = favoriteService ?? FavoriteService(),
       _authService = authService ?? AuthService() {
    _connectivitySubscription = _connectivityService.onlineChanges.listen((
      isOnline,
    ) async {
      if (!isOnline) {
        return;
      }

      final userId = await _authService.getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }

      await _favoriteService.syncWishlist(userId);
      await fetchWishlistItems();
    });
  }

  final FavoriteService _favoriteService;
  final AuthService _authService;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  late final StreamSubscription<bool> _connectivitySubscription;

  bool isFavorite(String productId) =>
      items.any((item) => item.productId == productId);

  Future<void> syncFavoriteStatus(String productId) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      removeWhereProductId(productId);
      return;
    }

    try {
      final favorite = await _favoriteService.fetchFavorite(
        userId: userId,
        productId: productId,
      );

      removeWhereProductId(productId);
      if (favorite != null) {
        addItem(favorite);
      }
      clearError();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<String> toggleFavorite(String productId) async {
    if (productId.isEmpty) {
      throw Exception('Please choose a valid product.');
    }

    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to manage your wishlist.');
    }

    setLoading(true);
    setError(null);

    try {
      final existing = items.cast<FavoriteModel?>().firstWhere(
        (item) => item?.productId == productId,
        orElse: () => null,
      );

      if (existing != null) {
        await _favoriteService.removeFavorite(
          userId: userId,
          productId: productId,
        );
        removeById(existing.id);
        return 'Removed from wishlist.';
      }

      final favorite = await _favoriteService.addFavorite(
        userId: userId,
        productId: productId,
      );
      upsertItem(favorite);
      return 'Added to wishlist.';
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      setError(message);
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<List<WishlistItemModel>> fetchWishlistItems() async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to view your wishlist.');
    }

    setLoading(true);
    setError(null);

    try {
      final wishlistItems = await _favoriteService.fetchWishlistItems(
        userId: userId,
      );
      setItems(wishlistItems.map((item) => item.favorite).toList());
      return wishlistItems;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      setError(message);
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  void removeWhereProductId(String productId) {
    final matchingIds = items
        .where((item) => item.productId == productId)
        .map((item) => item.id)
        .toList();

    for (final id in matchingIds) {
      removeById(id);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
