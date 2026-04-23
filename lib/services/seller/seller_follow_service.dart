import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';

class SellerFollowService {
  SellerFollowService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<SellerFollowModel?> fetchFollow({
    required String userId,
    required String sellerId,
  }) async {
    try {
      final data = await _supabase
          .from('seller_follows')
          .select()
          .eq('user_id', userId)
          .eq('seller_id', sellerId)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return SellerFollowModel.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Unable to load seller follow status right now.');
    }
  }

  Future<SellerFollowModel> followSeller({
    required String userId,
    required String sellerId,
  }) async {
    try {
      final inserted = await _supabase
          .from('seller_follows')
          .insert({
            'user_id': userId,
            'seller_id': sellerId,
          })
          .select()
          .single();

      return SellerFollowModel.fromMap(Map<String, dynamic>.from(inserted));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final existing = await fetchFollow(userId: userId, sellerId: sellerId);
        if (existing != null) {
          return existing;
        }
      }
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Unable to follow this seller right now.');
    }
  }

  Future<void> unfollowSeller({
    required String userId,
    required String sellerId,
  }) async {
    try {
      await _supabase
          .from('seller_follows')
          .delete()
          .eq('user_id', userId)
          .eq('seller_id', sellerId);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Unable to unfollow this seller right now.');
    }
  }

  Future<int> fetchFollowerCount(String sellerId) async {
    try {
      final rows = await _supabase
          .from('seller_follows')
          .select('id')
          .eq('seller_id', sellerId);
      return (rows as List).length;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Unable to load follower count right now.');
    }
  }

  Future<List<FollowingSellerItemModel>> fetchFollowingSellers({
    required String userId,
  }) async {
    try {
      final data = await _supabase
          .from('seller_follows')
          .select('id, user_id, seller_id, created_at, seller:users!seller_follows_seller_id_fkey(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (data as List)
          .map(
            (item) => FollowingSellerItemModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Unable to load followed sellers right now.');
    }
  }

  Future<List<FollowerItemModel>> fetchFollowers({
    required String sellerId,
  }) async {
    try {
      final data = await _supabase
          .from('seller_follows')
          .select(
            'id, user_id, seller_id, created_at, follower:users!seller_follows_user_id_fkey(*)',
          )
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      return (data as List)
          .map(
            (item) => FollowerItemModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Unable to load followers right now.');
    }
  }
}
