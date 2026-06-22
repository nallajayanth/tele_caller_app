import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/models/telecaller_model.dart';

final activeUserProvider = StateNotifierProvider<AuthNotifier, TelecallerModel?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<TelecallerModel?> {
  AuthNotifier() : super(null) {
    _loadSession();
  }

  static const String _sessionKey = 'auth_session';

  void _loadSession() {
    final box = Hive.box('settings');
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
      final response = await Supabase.instance.client
          .from('telecallers')
          .select()
          .eq('phone_number', phoneNumber)
          .maybeSingle();
      if (response == null) return false;

      final telecaller = TelecallerModel.fromJson(response);
      bool isPinValid = false;
      if (pin == telecaller.pin) {
        isPinValid = true;
      }

      if (isPinValid) {
        final box = Hive.box('settings');
        // Save session in Hive settings
        await box.put(_sessionKey, telecaller.toJson());
        
        // Update device_id to a valid UUID-syntax based on the logged-in staff's phone number!
        final formattedDeviceId = phoneNumber.length == 10 
            ? '00000000-0000-0000-0000-${phoneNumber.padLeft(12, '0')}'
            : phoneNumber;
        await box.put('device_id', formattedDeviceId);
        
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
    await box.delete(_sessionKey);
    
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
    final response = await Supabase.instance.client
        .from('telecallers')
        .select();
    return (response as List<dynamic>)
        .map((json) => TelecallerModel.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});
