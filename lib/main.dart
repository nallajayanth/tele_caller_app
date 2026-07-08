import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data/models/call_log_model.dart';
import 'data/models/deleted_log_model.dart';
import 'core/services/fcm_service.dart';
import 'core/services/encryption_service.dart';
import 'core/services/location_service.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Cloud Database
  await Firebase.initializeApp();

  // Initialize FCM Push Notification Services
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FCMService.instance.init();

  // Initialize background location services
  await LocationService.initializeService();

  // Ensure Firebase Anonymous Authentication for Firestore Rules
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Firebase Anonymous Auth failed: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await Hive.initFlutter();
  Hive.registerAdapter(CallLogModelAdapter());
  Hive.registerAdapter(DeletedLogModelAdapter());
  await Hive.openBox<CallLogModel>('call_logs');
  await Hive.openBox<DeletedLogModel>('deleted_logs');
  await Hive.openBox('settings');
  await EncryptionService.openEncryptedBox('secure_settings');

  runApp(const ProviderScope(child: TelecallerApp()));

  // Process launch notification payload once navigator context is mounted
  FCMService.instance.handleInitialNotification();
}
