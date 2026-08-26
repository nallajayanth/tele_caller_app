import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../data/models/visit_model.dart';
import 'auth_providers.dart';

final visitsProvider = StateNotifierProvider<VisitsNotifier, AsyncValue<List<VisitModel>>>((ref) {
  final user = ref.watch(activeUserProvider);
  return VisitsNotifier(user?.phoneNumber, user?.name, user?.role);
});

class VisitsNotifier extends StateNotifier<AsyncValue<List<VisitModel>>> {
  final String? _userPhone;
  final String? _userName;
  final String? _userRole;

  VisitsNotifier(this._userPhone, this._userName, this._userRole) : super(const AsyncValue.loading()) {
    if (_userPhone != null && _userPhone.isNotEmpty) {
      loadTodayVisits();
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> loadTodayVisits() async {
    if (_userPhone == null || _userPhone.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      Query query = FirebaseFirestore.instance.collection('customer_visits');
      if (_userRole != 'admin') {
        query = query.where('staff_phone', isEqualTo: _userPhone);
      }

      final snap = await query.get();

      final visits = snap.docs.map((doc) => VisitModel.fromJson(doc.data() as Map<String, dynamic>)).toList();
      visits.sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
      state = AsyncValue.data(visits);
    } catch (e, st) {
      debugPrint('Failed to load visits: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> logVisit({
    required String customerName,
    required String customerType,
    required String address,
    required String remarks,
    String? nextFollowUpDate,
    String? photoUrl,
    double? targetLat,
    double? targetLng,
    double? arrivalLat,
    double? arrivalLng,
  }) async {
    if (_userPhone == null || _userPhone.isEmpty) return false;

    try {
      // 1. Capture or use passed arrival GPS location
      double finalLat = arrivalLat ?? 0.0;
      double finalLng = arrivalLng ?? 0.0;

      if (finalLat == 0.0 || finalLng == 0.0) {
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (_) {
          position = await Geolocator.getLastKnownPosition();
        }
        finalLat = position?.latitude ?? 0.0;
        finalLng = position?.longitude ?? 0.0;
      }

      final now = DateTime.now();

      // 2. Visit Verification Engine: Check if distance to registered target > 100 meters
      bool isMismatch = false;
      if (targetLat != null && targetLng != null && finalLat != 0.0) {
        final distanceMeters = Geolocator.distanceBetween(
          finalLat,
          finalLng,
          targetLat,
          targetLng,
        );
        if (distanceMeters > 100) {
          isMismatch = true;
          debugPrint('VISIT VERIFICATION ALERT: Location mismatch ($distanceMeters meters > 100m limit)');
        }
      }

      final docRef = FirebaseFirestore.instance.collection('customer_visits').doc();

      final visit = VisitModel(
        id: docRef.id,
        staffPhone: _userPhone,
        staffName: _userName ?? 'Staff Member',
        customerName: customerName,
        customerType: customerType,
        address: address,
        arrivalTime: now,
        arrivalLat: finalLat,
        arrivalLng: finalLng,
        targetLat: targetLat,
        targetLng: targetLng,
        photoUrl: photoUrl,
        photoTimestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        remarks: remarks,
        nextFollowUpDate: nextFollowUpDate,
        isLocationMismatch: isMismatch,
      );

      await docRef.set(visit.toJson());

      // 3. Append geotag point to today's journey route points in Firestore
      if (finalLat != 0.0 && finalLng != 0.0) {
        final dateStr = DateFormat('yyyy-MM-dd').format(now);
        final attendanceDocId = '${_userPhone}_$dateStr';
        await FirebaseFirestore.instance
            .collection('attendance_logs')
            .doc(attendanceDocId)
            .collection('route_points')
            .add({
          'latitude': finalLat,
          'longitude': finalLng,
          'speed': 0.0,
          'accuracy': 5.0,
          'is_mocked': false,
          'timestamp': now.toIso8601String(),
          'log_id': docRef.id,
          'label': customerName,
        });

        // Also update staff's latest live position
        await FirebaseFirestore.instance
            .collection('staff_locations')
            .doc(_userPhone)
            .set({
          'name': _userName ?? 'Staff Member',
          'phoneNumber': _userPhone,
          'latitude': finalLat,
          'longitude': finalLng,
          'timestamp': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));
      }

      await loadTodayVisits();
      return true;
    } catch (e) {
      debugPrint('Failed to log visit: $e');
      return false;
    }
  }
}
