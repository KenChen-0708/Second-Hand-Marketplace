import 'package:supabase_flutter/supabase_flutter.dart';
import 'entity_state.dart';
import '../models/admin_log_model.dart';

class AdminLogState extends EntityState<AdminLogModel> {
  final _supabase = Supabase.instance.client;

  Future<void> fetchNotificationLogs() async {
    setLoading(true);
    setError(null);
    try {
      final response = await _supabase
          .from('admin_logs')
          .select()
          .eq('action', 'broadcast_notification')
          .order('created_at', ascending: false);

      final logs = (response as List)
          .map((l) => AdminLogModel.fromMap(Map<String, dynamic>.from(l)))
          .toList();
      setItems(logs);
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }
}