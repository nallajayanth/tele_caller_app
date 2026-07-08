import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../data/models/telecaller_model.dart';
import '../core/services/fcm_service.dart';

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

  Future<bool> login(String phoneNumber, String pin) async {
    try {
      final client = FirebaseFirestore.instance;
      
      // Auto-seed: If no users exist yet in Firestore, seed a default admin
      final checkSnap = await client.collection('telecallers').limit(1).get();
      if (checkSnap.docs.isEmpty) {
        await client.collection('telecallers').doc('1234567890').set({
          'phone_number': '1234567890',
          'name': 'Default Admin',
          'role': 'admin',
          'pin': '1234',
        });
      }

      final doc = await client
          .collection('telecallers')
          .doc(phoneNumber)
          .get();
      if (!doc.exists || doc.data() == null) return false;

      final telecaller = TelecallerModel.fromJson(doc.data()!);
      bool isPinValid = false;
      if (pin == telecaller.pin) {
        isPinValid = true;
      }

      if (isPinValid) {
        final box = Hive.box('settings');
        final secureBox = Hive.box('secure_settings');
        // Save session in Hive secure settings
        await secureBox.put(_sessionKey, telecaller.toJson());
        
        // Update device_id to a valid UUID-syntax based on the logged-in staff's phone number!
        final formattedDeviceId = phoneNumber.length == 10 
            ? '00000000-0000-0000-0000-${phoneNumber.padLeft(12, '0')}'
            : phoneNumber;
        await box.put('device_id', formattedDeviceId);
        
        // Register FCM push token for this device
        await FCMService.instance.registerUserToken(phoneNumber);

        state = telecaller;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    final box = Hive.box('settings');
    final secureBox = Hive.box('secure_settings');
    await secureBox.delete(_sessionKey);
    
    // Re-generate a generic unique device ID upon logout for security
    await box.put('device_id', const Uuid().v4());
    
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
