import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LockService {
  const LockService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  static const _saltKey = 'app_lock_salt';
  static const _hashKey = 'app_lock_hash';

  Future<bool> hasPin() async {
    return await _storage.containsKey(key: _hashKey);
  }

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('PIN은 숫자 4~8자리여야 합니다.');
    }
    final random = Random.secure();
    final salt = base64UrlEncode(
      List<int>.generate(24, (_) => random.nextInt(256)),
    );
    // Write the salt and hash together so changing the PIN is a single write.
    await _storage.write(key: _hashKey, value: '$salt:${_hash(pin, salt)}');
  }

  Future<bool> verifyPin(String pin) async {
    final credential = await _storage.read(key: _hashKey);
    if (credential == null) return false;

    final separator = credential.indexOf(':');
    if (separator >= 0) {
      final salt = credential.substring(0, separator);
      final hash = credential.substring(separator + 1);
      return _constantTimeEquals(hash, _hash(pin, salt));
    }
    final salt = await _storage.read(key: _saltKey);
    return salt != null && _constantTimeEquals(credential, _hash(pin, salt));
  }

  Future<void> removePin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  bool _constantTimeEquals(String first, String second) {
    if (first.length != second.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first.codeUnitAt(index) ^ second.codeUnitAt(index);
    }
    return difference == 0;
  }
}
