import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_providers.dart';
import 'attendance_providers.dart';
import '../data/models/attendance_model.dart';

class ShiftStatusNotifier extends StateNotifier<bool> {
  final Ref _ref;
  StreamSubscription<Position>? _positionSubscription;
  ProviderSubscription? _attendanceSubscription;

  ShiftStatusNotifier(this._ref) : super(false) {
    _checkRunningStatus();
    _listenToAttendance();
  }

  void _listenToAttendance() {
    _attendanceSubscription?.close();
    _attendanceSubscription = _ref.listen<AsyncValue<AttendanceModel?>>(
      activeAttendanceProvider,
      (previous, next) {
        final activeUser = _ref.read(activeUserProvider);
        if (activeUser == null || activeUser.role != 'staff' || !activeUser.isFieldStaff) {
          if (state) {
            endShift();
          }
          return;
        }

        next.whenData((attendance) {
          final isActive = attendance != null && attendance.isActive;
          if (isActive) {
            if (!state) {
              startShift();
            }
          } else {
            if (state) {
              endShift();
            }
          }
        });
      },
      fireImmediately: true,
    );
  }

  Future<void> _checkRunningStatus() async {
    final running = await FlutterBackgroundService().isRunning();
    state = running;
    if (running) {
      final activeUser = _ref.read(activeUserProvider);
      if (activeUser != null && activeUser.role == 'staff' && activeUser.isFieldStaff) {
        _startForegroundTracking(activeUser.phoneNumber, activeUser.name);
      } else {
        // If service is running but user is not field staff or logged out, stop it
        endShift();
      }
    }
  }

  /// Requests permission and starts the background location shift service.
  Future<bool> startShift() async {
    final activeUser = _ref.read(activeUserProvider);
    if (activeUser == null || activeUser.role != 'staff' || !activeUser.isFieldStaff) {
      return false;
    }

    // 1. Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 2. Request permission (Foreground)
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // 3. Start background location service
    final backgroundService = FlutterBackgroundService();
    final success = await backgroundService.startService();
    if (success) {
      state = true;
      // Start foreground fallback stream
      _startForegroundTracking(activeUser.phoneNumber, activeUser.name);

      // Wait for port binding to complete then invoke initTask
      await Future.delayed(const Duration(milliseconds: 500));
      backgroundService.invoke('initTask', {
        'phoneNumber': activeUser.phoneNumber,
        'name': activeUser.name,
      });
    }
    return success;
  }

  /// Stops the background location service and marks staff offline.
  Future<void> endShift() async {
    final activeUser = _ref.read(activeUserProvider);
    _stopForegroundTracking();

    final backgroundService = FlutterBackgroundService();
    backgroundService.invoke('stopService');
    state = false;

    final phone = activeUser?.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('staff_locations')
            .doc(phone)
            .update({'isOnline': false});
      } catch (_) {}
    }
  }

  void _startForegroundTracking(String phone, String name) {
    _positionSubscription?.cancel();
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 15, // update when moved 15 meters
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      FirebaseFirestore.instance
          .collection('staff_locations')
          .doc(phone)
          .set({
        'name': name,
        'phoneNumber': phone,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));
    }, onError: (_) {});
  }

  void _stopForegroundTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  void dispose() {
    _attendanceSubscription?.close();
    _stopForegroundTracking();
    super.dispose();
  }
}

final shiftStatusProvider = StateNotifierProvider<ShiftStatusNotifier, bool>((ref) {
  return ShiftStatusNotifier(ref);
});
