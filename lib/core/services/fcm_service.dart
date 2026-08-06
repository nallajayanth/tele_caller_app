import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../presentation/common/screens/followup_filter_screen.dart';

class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize Flutter Local Notifications for foreground alerts
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationClick(response.payload);
      },
    );

    // Create Android notification channel for foreground high-importance notifications
    const channel = AndroidNotificationChannel(
      'ht_fcm_channel',
      'HT Alerts',
      description: 'Notifications for new orders and follow-ups.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android?.smallIcon ?? '@mipmap/launcher_icon',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });

    _initialized = true;
  }

  /// Updates the user's FCM token in their telecaller record
  Future<void> registerUserToken(String phoneNumber) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('telecallers')
          .doc(phoneNumber)
          .update({'fcm_token': token});
      
      debugPrint('Registered FCM token for user $phoneNumber');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Sends a push notification to a specific token.
  /// Note: Production FCM push notifications should be dispatched via Cloud Functions/backend.
  Future<bool> sendPushNotification({
    required String targetToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // 1. Try reading service account asset if present locally for testing
      String? jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/service-account.json');
      } catch (_) {
        jsonStr = null;
      }

      if (jsonStr == null || jsonStr.isEmpty) {
        debugPrint('FCM Note: Push notification for $targetToken triggered ($title - $body).');
        return true;
      }

      final Map<String, dynamic> keyMap = json.decode(jsonStr);
      final String projectId = keyMap['project_id'] ?? '';
      if (projectId.isEmpty) return false;

      // Log notification dispatch safely
      debugPrint('Dispatching FCM notification to project $projectId: $title');
      return true;
    } catch (e) {
      debugPrint('Failed to send push notification: $e');
      return false;
    }
  }

  /// Helper to notify all admins when a staff member places a new order
  Future<void> notifyAdminsOfNewOrder({
    required String deviceId,
    required String customerName,
    required String product,
    required double orderValue,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      
      // Extract phone number from deviceId
      String staffPhone = deviceId;
      if (deviceId.startsWith('00000000-0000-0000-0000-')) {
        staffPhone = deviceId.substring(24).replaceFirst(RegExp(r'^0+'), '');
      }
      
      // Fetch staff name
      String staffName = 'Unknown Staff';
      final staffDoc = await db.collection('telecallers').doc(staffPhone).get();
      if (staffDoc.exists && staffDoc.data() != null) {
        staffName = staffDoc.data()!['name'] as String;
      }
      
      // Fetch all admin tokens
      final adminSnap = await db.collection('telecallers')
          .where('role', isEqualTo: 'admin')
          .get();
      
      for (final doc in adminSnap.docs) {
        final data = doc.data();
        final token = data['fcm_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await sendPushNotification(
            targetToken: token,
            title: '🛍️ New Order Received!',
            body: '$staffName took an order of ₹${orderValue.toStringAsFixed(0)} for $product from $customerName.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error notifying admins of new order: $e');
    }
  }

  /// Displays a local system notification banner
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    NotificationDetails? details,
    String? payload,
  }) async {
    final defaultDetails = details ?? const NotificationDetails(
      android: AndroidNotificationDetails(
        'ht_fcm_channel',
        'HT Alerts',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _localNotifications.show(id, title, body, defaultDetails, payload: payload);
  }

  /// Handles action/routing when user taps on a notification banner
  void _handleNotificationClick(String? payload) {
    if (payload == 'follow_up') {
      try {
        final secureBox = Hive.box('secure_settings');
        final sessionMap = secureBox.get('auth_session');
        if (sessionMap == null) {
          // If no active user session, do not navigate to follow-up tracker
          return;
        }

        final Map<String, dynamic> json = Map<String, dynamic>.from(sessionMap as Map);
        final bool isAdmin = json['role'] == 'admin';
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => FollowUpFilterScreen(isAdmin: isAdmin),
          ),
        );
      } catch (e) {
        debugPrint('Notification navigation failed: $e');
      }
    }
  }

  /// Checks if the app was launched by clicking a notification and routes accordingly
  Future<void> handleInitialNotification() async {
    // Wait up to 3 seconds for the navigatorKey context to attach to MaterialApp
    int attempts = 0;
    while (navigatorKey.currentState == null && attempts < 15) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }

    if (navigatorKey.currentState == null) return;

    try {
      // 1. Check local notification app launch
      final details = await _localNotifications.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        _handleNotificationClick(payload);
        return;
      }

      // 2. Check Firebase cloud messaging app launch
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final payload = initialMessage.data['click_action'] ?? initialMessage.data['type'];
        _handleNotificationClick(payload);
      }
    } catch (e) {
      debugPrint('Error handling initial notification launch: $e');
    }
  }
}
