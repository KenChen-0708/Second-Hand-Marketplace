import '../models/models.dart';
import '../services/order/order_service.dart';
import 'entity_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DisputeState extends EntityState<DisputeModel> {
  final _supabase = Supabase.instance.client;

  Future<void> fetchAllDisputes() async {
    setLoading(true);
    setError(null);
    try {
      final response = await _supabase
          .from('disputes')
          .select()
          .order('created_at', ascending: false);

      final disputes = (response as List)
          .map((m) => DisputeModel.fromMap(m))
          .toList();
      setItems(disputes);
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  Future<void> resolveDispute({
    required String disputeId,
    required String orderId,
    required String resolutionStatus,
    required String resolutionNotes,
  }) async {
    setLoading(true);
    try {
      // 1. Update Dispute record
      await _supabase.from('disputes').update({
        'status': 'resolved',
        'resolution_notes': resolutionNotes,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', disputeId);

      // 2. Update Order status
      await OrderService().updateOrderStatus(orderId, resolutionStatus);

      // 3. Update local state
      final existingDispute = getById(disputeId);
      if (existingDispute != null) {
        upsertItem(existingDispute.copyWith(
          status: 'resolved',
          resolutionNotes: resolutionNotes,
          resolvedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}
