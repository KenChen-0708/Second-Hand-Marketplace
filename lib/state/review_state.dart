import 'entity_state.dart';
import '../models/review_model.dart';
import '../services/review/review_service.dart';

class ReviewState extends EntityState<ReviewModel> {
  final ReviewService _reviewService = ReviewService();

  Future<void> submitReview(ReviewModel review) async {
    setLoading(true);
    setError(null);
    try {
      await _reviewService.submitReview(review);
      addItem(review);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}
