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
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to submit review: $e');
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
