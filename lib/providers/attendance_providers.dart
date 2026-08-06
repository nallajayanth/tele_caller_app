import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/models/attendance_model.dart';
import '../core/services/location_permission_helper.dart';
import 'auth_providers.dart';

final activeAttendanceProvider = StateNotifierProvider<AttendanceNotifier, AsyncValue<AttendanceModel?>>((ref) {
  final user = ref.watch(activeUserProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return AttendanceNotifier(user?.phoneNumber, user?.name, deviceId);
});

class AttendanceNotifier extends StateNotifier<AsyncValue<AttendanceModel?>> {
  final String? _userPhone;
  final String? _userName;
  final String _deviceId;

  AttendanceNotifier(this._userPhone, this._userName, this._deviceId)
      : super(const AsyncValue.loading()) {
    if (_userPhone != null && _userPhone.isNotEmpty) {
      loadTodayAttendance();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> loadTodayAttendance() async {
    if (_userPhone == null || _userPhone.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final snap = await FirebaseFirestore.instance
          .collection('attendance_logs')
          .where('staff_phone', isEqualTo: _userPhone)
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final model = AttendanceModel.fromJson(snap.docs.first.data());
        state = AsyncValue.data(model);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      debugPrint('Error loading attendance log: $e');
      // Set data(null) instead of error state so UI shows Start Duty card gracefully
      state = const AsyncValue.data(null);
    }
  }

  Future<bool> startDuty({String? selfieUrl}) async {
    if (_userPhone == null || _userPhone.isEmpty) return false;

    try {
      state = const AsyncValue.loading();
      
      // Prompt OS location permission dialog if denied
      await LocationPermissionHelper.checkAndRequestPermission();

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final docId = '${_userPhone}_$todayStr';

      final newAttendance = AttendanceModel(
        id: docId,
        staffPhone: _userPhone,
        staffName: _userName ?? 'Staff Member',
        date: todayStr,
        startTime: now,
        startLatitude: position?.latitude ?? 0.0,
        startLongitude: position?.longitude ?? 0.0,
        startBattery: 100,
        startNetwork: 'Online',
        deviceId: _deviceId,
        startSelfieUrl: selfieUrl,
        isActive: true,
      );

      await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(docId)
          .set(newAttendance.toJson(), SetOptions(merge: true));

      // Trigger background tracking service
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
      service.invoke('initTask', {
        'phoneNumber': _userPhone,
        'name': _userName,
      });

      state = AsyncValue.data(newAttendance);
      return true;
    } catch (e, st) {
      debugPrint('Failed to start duty: $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> endDuty() async {
    final current = state.value;
    if (current == null || !current.isActive) return false;

    try {
      state = const AsyncValue.loading();

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      final now = DateTime.now();
      final diffMinutes = now.difference(current.startTime).inMinutes;

      final updated = current.copyWith(
        endTime: now,
        endLatitude: position?.latitude ?? current.startLatitude,
        endLongitude: position?.longitude ?? current.startLongitude,
        endBattery: 100,
        endNetwork: 'Online',
        totalWorkingMinutes: diffMinutes > 0 ? diffMinutes : 0,
        isActive: false,
      );

      await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(current.id)
          .update(updated.toJson());

      // Stop background tracking service on end duty
      final service = FlutterBackgroundService();
      service.invoke('stopService');

      state = AsyncValue.data(updated);
      return true;
    } catch (e, st) {
      debugPrint('Failed to end duty: $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
