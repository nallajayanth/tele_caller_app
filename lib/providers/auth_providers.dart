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
      final expectedPin = telecaller.role == 'admin' ? '176176' : '9095';
      if (pin == expectedPin) {
        final box = Hive.box('settings');
        // Save session in Hive settings
        await box.put(_sessionKey, telecaller.toJson());
        
        // Update device_id to a valid UUID-syntax based on the logged-in staff's phone number!
        // This isolates logs automatically because calls will be saved
        // with the formatted UUID as their deviceId and fetched accordingly.
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
