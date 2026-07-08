import '../../domain/repositories/call_log_repository.dart';
import '../datasources/firestore_datasource.dart';
import '../models/call_log_model.dart';

class CallLogRepositoryImpl implements CallLogRepository {
  final FirestoreDataSource _dataSource;

  CallLogRepositoryImpl(this._dataSource);

  @override
  Future<List<CallLogModel>> getAllLogs() => _dataSource.getAllLogs();

  @override
  Future<List<CallLogModel>> getLogsByDeviceId(String deviceId) =>
      _dataSource.getLogsByDeviceId(deviceId);

  @override
  Future<void> addLog(CallLogModel log) => _dataSource.addLog(log);

  @override
  Future<void> updateLog(CallLogModel log) => _dataSource.updateLog(log);

  @override
  Future<void> deleteLog(String id) => _dataSource.deleteLog(id);
}
