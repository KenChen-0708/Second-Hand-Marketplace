import '../models/models.dart';
import '../services/auth/auth_service.dart';
import '../services/notification/notification_service.dart';
import '../services/seller/seller_follow_service.dart';
import 'entity_state.dart';

class SellerFollowState extends EntityState<SellerFollowModel> {
  SellerFollowState({
    SellerFollowService? sellerFollowService,
    AuthService? authService,
    NotificationService? notificationService,
  }) : _sellerFollowService = sellerFollowService ?? SellerFollowService(),
       _authService = authService ?? AuthService(),
       _notificationService = notificationService ?? NotificationService();

  final SellerFollowService _sellerFollowService;
  final AuthService _authService;
  final NotificationService _notificationService;
  final Map<String, int> _followerCounts = {};
  String? _activeUserId;

  bool isFollowing(String sellerId) =>
      items.any((item) => item.sellerId == sellerId);

  int followerCountFor(String sellerId) => _followerCounts[sellerId] ?? 0;

  void updateCurrentUser(UserModel? user) {
    final userId = user?.id;
    if (_activeUserId == userId) {
      return;
    }

    _activeUserId = userId;
    _followerCounts.clear();
    clear();
  }

  Future<void> syncFollowStatus(String sellerId) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty || userId == sellerId) {
      _removeWhereSellerId(sellerId);
      return;
    }

    try {
      final follow = await _sellerFollowService.fetchFollow(
        userId: userId,
        sellerId: sellerId,
      );

      _removeWhereSellerId(sellerId);
      if (follow != null) {
        addItem(follow);
      } else {
        notifyListeners();
      }
      clearError();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<void> refreshFollowerCount(String sellerId) async {
    try {
      final count = await _sellerFollowService.fetchFollowerCount(sellerId);
      _followerCounts[sellerId] = count;
      notifyListeners();
      clearError();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<String> toggleFollow(String sellerId, {String? followerName}) async {
    if (sellerId.isEmpty) {
      throw Exception('Please choose a valid seller.');
    }

    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to follow sellers.');
    }

    if (userId == sellerId) {
      throw Exception('You cannot follow your own seller profile.');
    }

    setLoading(true);
    setError(null);

    try {
      final existing = items.cast<SellerFollowModel?>().firstWhere(
        (item) => item?.sellerId == sellerId,
        orElse: () => null,
      );

      if (existing != null) {
        await _sellerFollowService.unfollowSeller(
          userId: userId,
          sellerId: sellerId,
        );
        removeById(existing.id);
        _followerCounts[sellerId] = (_followerCounts[sellerId] ?? 1) - 1;
        if ((_followerCounts[sellerId] ?? 0) < 0) {
          _followerCounts[sellerId] = 0;
        }
        notifyListeners();
        return 'Seller unfollowed.';
      }

      final follow = await _sellerFollowService.followSeller(
        userId: userId,
        sellerId: sellerId,
      );
      upsertItem(follow);
      _followerCounts[sellerId] = (_followerCounts[sellerId] ?? 0) + 1;
      final resolvedFollowerName =
          followerName ?? await _resolveFollowerName(userId);
      await _notificationService.notifySellerFollowed(
        sellerId: sellerId,
        followerName: resolvedFollowerName,
      );
      notifyListeners();
      return 'Seller followed.';
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      setError(message);
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  void _removeWhereSellerId(String sellerId) {
    final matchingIds = items
        .where((item) => item.sellerId == sellerId)
        .map((item) => item.id)
        .toList();

    for (final id in matchingIds) {
      removeById(id);
    }
  }

  Future<String> _resolveFollowerName(String userId) async {
    try {
      final profile = await _authService.fetchProfileById(userId);
      return profile.name;
    } catch (_) {
      return 'Someone';
    }
  }
}
