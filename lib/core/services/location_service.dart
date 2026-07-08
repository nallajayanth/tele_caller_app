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

  /// Helper to get current location and update it to Firestore with lastKnown fallback
  static Future<void> _updateLocation(ServiceInstance service, String phone, String? name) async {
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('Background location getCurrentPosition failed: $e');
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (position != null) {
      try {
        await FirebaseFirestore.instance
            .collection('staff_locations')
            .doc(phone)
            .set({
          'name': name ?? 'Staff Member',
          'phoneNumber': phone,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));
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

    service.on('stopService').listen((event) async {
      // Mark employee offline in database on service termination
      if (phoneNumber != null) {
        try {
          await FirebaseFirestore.instance
              .collection('staff_locations')
              .doc(phoneNumber!)
              .update({'isOnline': false});
        } catch (_) {}
      }
      service.stopSelf();
    });

    // 3. Start location polling loop (every 3 minutes)
    Timer.periodic(const Duration(minutes: 3), (timer) async {
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
