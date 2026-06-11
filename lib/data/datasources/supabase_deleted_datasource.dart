import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deleted_log_model.dart';

class SupabaseDeletedDatasource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<DeletedLogModel>> getAll() async {
    final response = await _client
        .from('deleted_logs')
        .select()
        .order('deleted_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => DeletedLogModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(DeletedLogModel log) async {
    await _client.from('deleted_logs').insert(log.toJson());
  }

  Future<void> delete(String id) async {
    await _client.from('deleted_logs').delete().eq('id', id);
  }

  /// Deletes all logs in the recycle bin.
  /// Note: Supabase's PostgREST requires a filter to prevent accidental bulk deletions,
  /// so we use a non-matching dummy UUID filter.
  Future<void> deleteAll() async {
    await _client
        .from('deleted_logs')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
  }

  Future<DeletedLogModel?> getById(String id) async {
    final response = await _client
        .from('deleted_logs')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    return DeletedLogModel.fromJson(response);
  }

  Future<void> cleanup30Days() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await _client
        .from('deleted_logs')
        .delete()
        .lt('deleted_at', cutoff);
  }
}
