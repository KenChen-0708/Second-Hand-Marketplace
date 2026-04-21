import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class ReviewService {
  ReviewService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> submitReview(ReviewModel review) async {
    try {
      await _supabase.from('reviews').insert(review.toMap());
      
      // The seller's average rating is typically updated via a Database Trigger in Supabase
      // to ensure consistency.
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('You have already reviewed this order.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  Future<ReviewModel?> fetchReviewForOrder(String orderId, String reviewerId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select()
          .eq('order_id', orderId)
          .eq('reviewer_id', reviewerId)
          .maybeSingle();

      if (response == null) return null;
      return ReviewModel.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Error fetching review for order: $e');
      return null;
    }
  }

  /// Fetches reviews where the user is the reviewee (the seller)
  Future<List<ReviewModel>> fetchSellerReviews(String sellerId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('*, reviewer:users!reviews_reviewer_id_fkey(*)')
          .eq('reviewee_id', sellerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((r) => ReviewModel.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      print('Error fetching seller reviews: $e');
      return [];
    }
  }
}
