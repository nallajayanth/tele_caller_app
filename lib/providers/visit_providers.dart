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

      final snap = await query.orderBy('arrival_time', descending: true).get();

      final visits = snap.docs.map((doc) => VisitModel.fromJson(doc.data() as Map<String, dynamic>)).toList();
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
  }) async {
    if (_userPhone == null || _userPhone.isEmpty) return false;

    try {
      // 1. Capture current arrival GPS location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      final arrivalLat = position?.latitude ?? 0.0;
      final arrivalLng = position?.longitude ?? 0.0;
      final now = DateTime.now();

      // 2. Visit Verification Engine: Check if distance to registered target > 100 meters
      bool isMismatch = false;
      if (targetLat != null && targetLng != null && arrivalLat != 0.0) {
        final distanceMeters = Geolocator.distanceBetween(
          arrivalLat,
          arrivalLng,
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
        arrivalLat: arrivalLat,
        arrivalLng: arrivalLng,
        targetLat: targetLat,
        targetLng: targetLng,
        photoUrl: photoUrl,
        photoTimestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        remarks: remarks,
        nextFollowUpDate: nextFollowUpDate,
        isLocationMismatch: isMismatch,
      );

      await docRef.set(visit.toJson());

      await loadTodayVisits();
      return true;
    } catch (e) {
      debugPrint('Failed to log visit: $e');
      return false;
    }
  }
}
