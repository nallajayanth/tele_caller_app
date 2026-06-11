import 'package:hive_flutter/hive_flutter.dart';
import '../models/call_log_model.dart';

class HiveDataSource {
  static const String _logsBox = 'call_logs';

  Box<CallLogModel> get _box => Hive.box<CallLogModel>(_logsBox);

  Future<List<CallLogModel>> getAllLogs() async {
    final logs = _box.values.toList();
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  Future<List<CallLogModel>> getLogsByDeviceId(String deviceId) async {
    final logs = _box.values.where((l) => l.deviceId == deviceId).toList();
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  Future<void> addLog(CallLogModel log) async {
    await _box.put(log.id, log);
  }

  Future<void> updateLog(CallLogModel log) async {
    await _box.put(log.id, log);
  }

  Future<void> deleteLog(String id) async {
    await _box.delete(id);
  }
}
