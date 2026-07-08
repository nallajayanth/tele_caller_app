import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deleted_log_model.dart';

class FirestoreDeletedDatasource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('deleted_logs');

  Future<List<DeletedLogModel>> getAll() async {
    final querySnapshot = await _collection
        .orderBy('deleted_at', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => DeletedLogModel.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(DeletedLogModel log) async {
    await _collection.doc(log.id).set(log.toJson());
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }

  /// Deletes all logs in the recycle bin.
  Future<void> deleteAll() async {
    final snapshot = await _collection.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<DeletedLogModel?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return DeletedLogModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  Future<void> cleanup30Days() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    
    // In Firestore, if deleted_at is stored as ISO string, we can do string comparison,
    // or if it's stored as Timestamp we do timestamp comparison.
    // The original model toJson() usually converts DateTime to ISO8601 string or Timestamp.
    // Let's query by deleted_at field.
    final snapshot = await _collection
        .where('deleted_at', isLessThan: cutoff)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
