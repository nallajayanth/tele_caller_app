import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart';
import '../data/models/attendance_model.dart';
import '../core/services/location_permission_helper.dart';
import 'auth_providers.dart';

final activeAttendanceProvider = StateNotifierProvider<AttendanceNotifier, AsyncValue<AttendanceModel?>>((ref) {
  final user = ref.watch(activeUserProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return AttendanceNotifier(ref, user?.phoneNumber, user?.name, deviceId);
});

class AttendanceNotifier extends StateNotifier<AsyncValue<AttendanceModel?>> {
  final Ref _ref;
  final String? _userPhone;
  final String? _userName;
  final String _deviceId;

  AttendanceNotifier(this._ref, this._userPhone, this._userName, this._deviceId)
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

  Future<bool> startDuty({
    String? phone,
    String? name,
    String? deviceId,
    String? selfieUrl,
    Position? position,
  }) async {
    final targetPhone = phone ?? _userPhone;
    final targetName = name ?? _userName ?? 'Staff Member';
    final targetDeviceId = deviceId ?? _deviceId;
    if (targetPhone == null || targetPhone.isEmpty) return false;

    try {
      state = const AsyncValue.loading();
      
      final activeUser = _ref.read(activeUserProvider);
      final isField = activeUser != null && activeUser.role == 'staff' && activeUser.isFieldStaff;

      Position? pos;
      if (isField) {
        pos = position;
        if (pos == null) {
          // Prompt OS location permission dialog if denied
          await LocationPermissionHelper.checkAndRequestPermission();

          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10),
            );
          } catch (_) {
            try {
              pos = await Geolocator.getLastKnownPosition();
            } catch (_) {}
          }
        }
        if (pos == null) {
          throw Exception('Location (GPS) is required to start your duty shift.');
        }
      }

      int batteryLevel = 100;
      try {
        batteryLevel = await Battery().batteryLevel;
      } catch (_) {}

      String networkStatus = 'Disconnected';
      try {
        final lookup = await InternetAddress.lookup('example.com');
        if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
          networkStatus = 'Connected';
        }
      } catch (_) {}

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final docId = '${targetPhone}_$todayStr';

      final newAttendance = AttendanceModel(
        id: docId,
        staffPhone: targetPhone,
        staffName: targetName,
        date: todayStr,
        startTime: now,
        startLatitude: pos?.latitude ?? 0.0,
        startLongitude: pos?.longitude ?? 0.0,
        startBattery: batteryLevel,
        startNetwork: networkStatus,
        deviceId: targetDeviceId,
        startSelfieUrl: selfieUrl,
        isActive: true,
      );

      await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(docId)
          .set(newAttendance.toJson(), SetOptions(merge: true));

      // Update staff_locations live document immediately on startDuty
      try {
        await FirebaseFirestore.instance
            .collection('staff_locations')
            .doc(targetPhone)
            .set({
          'name': targetName,
          'phoneNumber': targetPhone,
          'latitude': pos?.latitude ?? 0.0,
          'longitude': pos?.longitude ?? 0.0,
          'timestamp': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to update staff_locations on startDuty: $e');
      }

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

      final activeUser = _ref.read(activeUserProvider);
      final isField = activeUser != null && activeUser.role == 'staff' && activeUser.isFieldStaff;

      Position? position;
      if (isField) {
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
      }

      int batteryLevel = 100;
      try {
        batteryLevel = await Battery().batteryLevel;
      } catch (_) {}

      String networkStatus = 'Disconnected';
      try {
        final lookup = await InternetAddress.lookup('example.com');
        if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
          networkStatus = 'Connected';
        }
      } catch (_) {}

      final now = DateTime.now();
      final diffMinutes = now.difference(current.startTime).inMinutes;

      final updated = current.copyWith(
        endTime: now,
        endLatitude: position?.latitude ?? current.startLatitude,
        endLongitude: position?.longitude ?? current.startLongitude,
        endBattery: batteryLevel,
        endNetwork: networkStatus,
        totalWorkingMinutes: diffMinutes > 0 ? diffMinutes : 0,
        isActive: false,
      );

      await FirebaseFirestore.instance
          .collection('attendance_logs')
          .doc(current.id)
          .update(updated.toJson());

      // Set staff as offline in staff_locations collection on duty end
      final phone = _userPhone ?? current.staffPhone;
      if (phone.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('staff_locations')
              .doc(phone)
              .set({
            'isOnline': false,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to update staff_locations on endDuty: $e');
        }
      }

      state = AsyncValue.data(updated);
      return true;
    } catch (e, st) {
      debugPrint('Failed to end duty: $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

// Selected date for admin attendance monitoring screen
final adminAttendanceDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Stream provider to watch all staff attendance logs for the selected date
final dailyAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final selectedDate = ref.watch(adminAttendanceDateProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

  return FirebaseFirestore.instance
      .collection('attendance_logs')
      .where('date', isEqualTo: dateStr)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => AttendanceModel.fromJson(doc.data()))
        .toList();
  });
});

