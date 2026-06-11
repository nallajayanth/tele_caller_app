import '../../data/models/call_log_model.dart';

abstract class CallLogRepository {
  Future<List<CallLogModel>> getAllLogs();
  Future<List<CallLogModel>> getLogsByDeviceId(String deviceId);
  Future<void> addLog(CallLogModel log);
  Future<void> updateLog(CallLogModel log);
  Future<void> deleteLog(String id);
}
