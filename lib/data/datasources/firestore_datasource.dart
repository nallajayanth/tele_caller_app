import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call_log_model.dart';

class FirestoreDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('call_logs');

  Future<List<CallLogModel>> getAllLogs() async {
    final querySnapshot = await _collection.get();
    
    final logs = querySnapshot.docs
        .map((doc) => CallLogModel.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  Future<List<CallLogModel>> getLogsByDeviceId(String deviceId) async {
    final querySnapshot = await _collection
        .where('device_id', isEqualTo: deviceId)
        .get();

    final logs = querySnapshot.docs
        .map((doc) => CallLogModel.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  Future<void> addLog(CallLogModel log) async {
    await _collection.doc(log.id).set(log.toJson());
  }

  Future<void> updateLog(CallLogModel log) async {
    await _collection.doc(log.id).update(log.toJson());
  }

  Future<void> deleteLog(String id) async {
    await _collection.doc(id).delete();
  }
}
