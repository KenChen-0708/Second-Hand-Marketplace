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

  Future<void> deleteLog(String id) async {
    try {
      // 1. Get the log entry first to identify the broadcast content
      final logResp = await _supabase
          .from('admin_logs')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      if (logResp != null) {
        final log = AdminLogModel.fromMap(Map<String, dynamic>.from(logResp));
        
        // 2. If it's a broadcast log, delete the actual notifications sent to users
        if (log.action == 'broadcast_notification' && log.details != null) {
          final String? title = log.details!['title'];
          // Use title and type='system' to identify broadcast notifications
          if (title != null && title.isNotEmpty) {
            await _supabase
                .from('notifications')
                .delete()
                .eq('title', title)
                .eq('notification_type', 'system');
          }
        }
      }

      // 3. Delete the log entry itself
      await _supabase.from('admin_logs').delete().eq('id', id);
      removeById(id);
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> clearNotificationLogs() async {
    setLoading(true);
    try {
      // 1. Delete all notifications of type 'system' (which includes broadcasts)
      // Note: This matches the default type used in broadcastToAllUsers
      await _supabase
          .from('notifications')
          .delete()
          .eq('notification_type', 'system');

      // 2. Delete all broadcast logs
      await _supabase
          .from('admin_logs')
          .delete()
          .eq('action', 'broadcast_notification');

      setItems([]);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}
