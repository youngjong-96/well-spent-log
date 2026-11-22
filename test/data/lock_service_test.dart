import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/data/services/lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lock = LockService();

  test('a legacy PIN can be verified, changed and disabled', () async {
    const salt = 'test-salt';
    FlutterSecureStorage.setMockInitialValues({
      'app_lock_salt': salt,
      'app_lock_hash': sha256.convert(utf8.encode('$salt:1234')).toString(),
    });

    expect(await lock.hasPin(), isTrue);
    expect(await lock.verifyPin('9876'), isFalse);
    expect(await lock.verifyPin('1234'), isTrue);

    await lock.setPin('5678');
    expect(await lock.verifyPin('1234'), isFalse);
    expect(await lock.verifyPin('5678'), isTrue);

    await lock.removePin();
    expect(await lock.hasPin(), isFalse);
    expect(await lock.verifyPin('5678'), isFalse);
  });

  test('incomplete legacy credentials never verify a PIN', () async {
    FlutterSecureStorage.setMockInitialValues({'app_lock_hash': 'orphaned'});
    expect(await lock.hasPin(), isTrue);
    expect(await lock.verifyPin('1234'), isFalse);
  });
}
