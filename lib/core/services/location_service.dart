import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  LocationService._();

  static const String _notificationChannelId = 'ht_fcm_channel';
  static const int _notificationId = 888;

  /// Initializes background service configurations. Should be called in main().
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'HT Shift Active',
        initialNotificationContent: 'Location tracking is active for your shift.',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  static double? _lastLat;
  static double? _lastLng;

  /// Helper to get current location, calculate KM distance, check Anti-fraud, and store route history
  static Future<void> _updateLocation(ServiceInstance service, String phone, String? name) async {
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Background location getCurrentPosition failed: $e');
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (position != null) {
      try {
        final isMocked = position.isMocked;

        // Anti-Fraud Alert: Log if fake GPS is detected
        if (isMocked) {
          debugPrint('ANTI-FRAUD WARNING: Fake/Mock GPS detected for staff $phone');
        }

        // 1. Update live location doc
        await FirebaseFirestore.instance
            .collection('staff_locations')
            .doc(phone)
            .set({
          'name': name ?? 'Staff Member',
          'phoneNumber': phone,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'accuracy': position.accuracy,
          'isMocked': isMocked,
          'timestamp': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));

        // 2. Append to today's route history
        final now = DateTime.now();
        final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final attendanceDocId = '${phone}_$dateStr';

        final routeRef = FirebaseFirestore.instance
            .collection('attendance_logs')
            .doc(attendanceDocId)
            .collection('route_points');

        await routeRef.add({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'accuracy': position.accuracy,
          'is_mocked': isMocked,
          'timestamp': now.toIso8601String(),
        });

        // 3. Compute distance increment if previous point exists
        if (_lastLat != null && _lastLng != null) {
          final distanceMeters = Geolocator.distanceBetween(
            _lastLat!,
            _lastLng!,
            position.latitude,
            position.longitude,
          );

          // Only increment if movement > 15m and speed reasonable (<150km/h) to filter GPS drift
          if (distanceMeters >= 15 && position.speed < 42) {
            final kmIncrement = distanceMeters / 1000.0;
            await FirebaseFirestore.instance
                .collection('attendance_logs')
                .doc(attendanceDocId)
                .set({
              'total_km': FieldValue.increment(kmIncrement),
            }, SetOptions(merge: true));
          }
        }

        _lastLat = position.latitude;
        _lastLng = position.longitude;
      } catch (e) {
        debugPrint('Failed to save background location to firestore: $e');
      }
    }
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Firebase inside the background isolate
    await Firebase.initializeApp();

    String? phoneNumber;
    String? staffName;

    // 2. Listen to initTask to receive user credentials safely from the main thread
    service.on('initTask').listen((event) async {
      phoneNumber = event?['phoneNumber'] as String?;
      staffName = event?['name'] as String?;
      
      if (phoneNumber != null && phoneNumber!.isNotEmpty) {
        await _updateLocation(service, phoneNumber!, staffName);
      }
    });

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    Timer? locationTimer;

    service.on('stopService').listen((event) async {
      locationTimer?.cancel();
      // Mark employee offline in database on service termination
      if (phoneNumber != null) {
        try {
          await FirebaseFirestore.instance
              .collection('staff_locations')
              .doc(phoneNumber!)
              .set({'isOnline': false}, SetOptions(merge: true));
        } catch (_) {}
      }
      service.stopSelf();
    });

    // 3. Start high-frequency location polling loop (every 45 seconds)
    locationTimer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      if (phoneNumber == null) return; // Wait until initialized

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: 'HT Shift Active',
            content: 'Sharing location during active work shift.',
          );
        }
      }

      await _updateLocation(service, phoneNumber!, staffName);
    });
  }
}
