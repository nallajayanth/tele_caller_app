import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/supabase_deleted_datasource.dart';
import '../data/models/call_log_model.dart';
import '../data/models/deleted_log_model.dart';

final _deletedDsProvider = Provider((_) => SupabaseDeletedDatasource());

class DeletedLogNotifier extends StateNotifier<List<DeletedLogModel>> {
  final SupabaseDeletedDatasource _ds;

  DeletedLogNotifier(this._ds) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _ds.cleanup30Days();
      await loadLogs();
    } catch (_) {}
  }

  Future<void> loadLogs() async {
    try {
      final logs = await _ds.getAll();
      state = logs;
    } catch (_) {}
  }

  Future<void> moveToBin(CallLogModel log) async {
    final deletedLog = DeletedLogModel(
      id: log.id,
      deletedAt: DateTime.now(),
      date: log.date,
      customerName: log.customerName,
      mobile: log.mobile,
      place: log.place,
      product: log.product,
      connectedStatus: log.connectedStatus,
      customerResponse: log.customerResponse,
      nextFollowUpDate: log.nextFollowUpDate,
      orderValue: log.orderValue,
      remarks: log.remarks,
      deviceId: log.deviceId,
    );
    await _ds.add(deletedLog);
    await loadLogs();
  }

  Future<void> permanentDelete(String id) async {
    await _ds.delete(id);
    await loadLogs();
  }

  Future<void> emptyBin() async {
    await _ds.deleteAll();
    state = [];
  }

  /// Removes from bin and returns the CallLogModel so caller can restore it.
  Future<CallLogModel?> restore(String id) async {
    final deleted = await _ds.getById(id);
    if (deleted == null) return null;
    await _ds.delete(id);
    await loadLogs();
    return CallLogModel(
      id: deleted.id,
      date: deleted.date,
      customerName: deleted.customerName,
      mobile: deleted.mobile,
      place: deleted.place,
      product: deleted.product,
      connectedStatus: deleted.connectedStatus,
      customerResponse: deleted.customerResponse,
      nextFollowUpDate: deleted.nextFollowUpDate,
      orderValue: deleted.orderValue,
      remarks: deleted.remarks,
      deviceId: deleted.deviceId,
    );
  }
}

final deletedLogProvider =
    StateNotifierProvider<DeletedLogNotifier, List<DeletedLogModel>>(
  (ref) => DeletedLogNotifier(ref.read(_deletedDsProvider)),
);
