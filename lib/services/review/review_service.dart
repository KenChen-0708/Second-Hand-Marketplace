import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class ReviewService {
  ReviewService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> submitReview(ReviewModel review) async {
    try {
      await _supabase.from('reviews').insert(review.toMap());
      
      // Optionally trigger a recalculation of the seller's average rating
      // This is usually best handled by a Postgres Trigger, but we can do it here if needed.
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }
}
