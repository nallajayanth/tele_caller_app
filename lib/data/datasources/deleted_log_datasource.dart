import 'package:hive_flutter/hive_flutter.dart';
import '../models/deleted_log_model.dart';

class DeletedLogDatasource {
  Box<DeletedLogModel> get _box => Hive.box<DeletedLogModel>('deleted_logs');

  List<DeletedLogModel> getAll() {
    return _box.values.toList()
      ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  }

  void add(DeletedLogModel log) => _box.put(log.id, log);

  void delete(String id) => _box.delete(id);

  Future<void> deleteAll() => _box.clear();

  DeletedLogModel? getById(String id) => _box.get(id);

  void cleanup30Days() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final expired = _box.values
        .where((l) => l.deletedAt.isBefore(cutoff))
        .map((l) => l.id)
        .toList();
    for (final id in expired) {
      _box.delete(id);
    }
  }
}
