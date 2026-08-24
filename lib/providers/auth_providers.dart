import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/telecaller_model.dart';
import '../core/services/fcm_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

final activeUserProvider = StateNotifierProvider<AuthNotifier, TelecallerModel?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<TelecallerModel?> {
  AuthNotifier() : super(null) {
    _loadSession();
    if (state != null) {
      FCMService.instance.registerUserToken(state!.phoneNumber);
    }
  }

  static const String _sessionKey = 'auth_session';

  void _loadSession() {
    final box = Hive.box('secure_settings');
    final sessionMap = box.get(_sessionKey);
    if (sessionMap != null) {
      try {
        final Map<String, dynamic> json = Map<String, dynamic>.from(sessionMap as Map);
        state = TelecallerModel.fromJson(json);
      } catch (_) {
        box.delete(_sessionKey);
      }
    }
  }

  Future<TelecallerModel?> validateCredentials(String phoneNumber, String pin) async {
    try {
      final client = FirebaseFirestore.instance;
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final queryPhone = cleanPhone.isNotEmpty ? cleanPhone : phoneNumber;

      final doc = await client
          .collection('telecallers')
          .doc(queryPhone)
          .get();
      if (!doc.exists || doc.data() == null) return null;

      final telecaller = TelecallerModel.fromJson(doc.data()!);
      if (pin == telecaller.pin) {
        return telecaller;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setUserSession(TelecallerModel telecaller) async {
    final box = Hive.box('settings');
    final secureBox = Hive.box('secure_settings');
    await secureBox.put(_sessionKey, telecaller.toJson());
    
    final phoneNumber = telecaller.phoneNumber;
    final formattedDeviceId = phoneNumber.length == 10 
        ? '00000000-0000-0000-0000-${phoneNumber.padLeft(12, '0')}'
        : phoneNumber;
    await box.put('device_id', formattedDeviceId);
    
    await FCMService.instance.registerUserToken(phoneNumber);

    state = telecaller;
  }

  Future<bool> login(String phoneNumber, String pin) async {
    final telecaller = await validateCredentials(phoneNumber, pin);
    if (telecaller != null) {
      await setUserSession(telecaller);
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    final user = state;
    final phone = user?.phoneNumber;

    // Explicitly set isOnline: false in Firestore staff_locations BEFORE clearing state
    if (phone != null && phone.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('staff_locations')
            .doc(phone)
            .set({
          'isOnline': false,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to set staff offline on signOut: $e');
      }
    }

    final box = Hive.box('settings');
    final secureBox = Hive.box('secure_settings');
    await secureBox.delete(_sessionKey);

    // Re-generate a generic unique device ID upon logout for security
    await box.put('device_id', const Uuid().v4());

    // Explicitly stop background location service if running on logout
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
      }
    } catch (_) {}

    state = null;
  }
}

// Reactive Device ID provider
final deviceIdProvider = Provider<String>((ref) {
  final activeUser = ref.watch(activeUserProvider);
  if (activeUser != null && activeUser.role == 'staff') {
    final phone = activeUser.phoneNumber;
    return '00000000-0000-0000-0000-${phone.padLeft(12, '0')}';
  }
  
  // Fallback to Hive cached device ID or a random UUID
  final box = Hive.box('settings');
  String? id = box.get('device_id');
  if (id == null) {
    id = const Uuid().v4();
    box.put('device_id', id);
  }
  if (id.length == 10 && RegExp(r'^\d+$').hasMatch(id)) {
    id = '00000000-0000-0000-0000-${id.padLeft(12, '0')}';
    box.put('device_id', id);
  }
  return id;
});

final telecallersProvider = FutureProvider<List<TelecallerModel>>((ref) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('telecallers')
        .get();
    return snapshot.docs
        .map((doc) => TelecallerModel.fromJson(doc.data()))
        .toList();
  } catch (_) {
    return [];
  }
});
