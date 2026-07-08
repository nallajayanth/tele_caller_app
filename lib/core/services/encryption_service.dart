import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class EncryptionService {
  EncryptionService._();

  static const _secureStorage = FlutterSecureStorage();
  static const _keyName = 'hive_secure_key';

  /// Opens a Hive box encrypted with AES using a hardware-backed secure storage key.
  static Future<Box> openEncryptedBox(String boxName) async {
    // 1. Read existing key from secure storage
    String? keyBase64 = await _secureStorage.read(key: _keyName);
    List<int> encryptionKey;

    if (keyBase64 == null) {
      // 2. Generate a new secure 256-bit key
      final newKey = Hive.generateSecureKey();
      keyBase64 = base64Url.encode(newKey);
      await _secureStorage.write(key: _keyName, value: keyBase64);
      encryptionKey = newKey;
    } else {
      // 3. Decode existing key
      encryptionKey = base64Url.decode(keyBase64);
    }

    // 4. Open and return the encrypted box
    return await Hive.openBox(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }
}
