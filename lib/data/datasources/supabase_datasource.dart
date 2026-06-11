import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/call_log_model.dart';

class SupabaseDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<CallLogModel>> getAllLogs() async {
    final response = await _client
        .from('call_logs')
        .select()
        .order('date', ascending: false);
    
    return (response as List<dynamic>)
        .map((json) => CallLogModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CallLogModel>> getLogsByDeviceId(String deviceId) async {
    final response = await _client
        .from('call_logs')
        .select()
        .eq('device_id', deviceId)
        .order('date', ascending: false);

    return (response as List<dynamic>)
        .map((json) => CallLogModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> addLog(CallLogModel log) async {
    await _client.from('call_logs').insert(log.toJson());
  }

  Future<void> updateLog(CallLogModel log) async {
    await _client.from('call_logs').update(log.toJson()).eq('id', log.id);
  }

  Future<void> deleteLog(String id) async {
    await _client.from('call_logs').delete().eq('id', id);
  }
}
