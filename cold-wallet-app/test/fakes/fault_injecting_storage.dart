import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';

const vaultEntry = 'cold_vault';
const vaultBackupEntry = 'cold_vault_backup';
const plainKeyEntry = 'cold_unlock_key';
const protectedKeyEntry = 'cold_unlock_key_protected';

/// In-memory secure storage with fault injection. The vault's plain and
/// protected stores land in the same map; their entry names differ.
class FaultInjectingStorage extends TestFlutterSecureStoragePlatform {
  FaultInjectingStorage() : super({});

  /// Writes to this key throw.
  String? failWritesTo;

  /// Reads of this key throw what [failReadsWith] builds.
  String? failReadsOf;
  Object Function() failReadsWith = () => Exception('injected read failure');

  /// Reads of this key wait [delay], so an operation in flight can be observed.
  String? delayReadsOf;
  Duration delay = const Duration(milliseconds: 50);

  final Map<String, int> reads = {};

  int readsOf(String key) => reads[key] ?? 0;

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) {
    if (key == failWritesTo) throw Exception('injected write failure for $key');
    return super.write(key: key, value: value, options: options);
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    reads[key] = readsOf(key) + 1;
    if (key == delayReadsOf) await Future<void>.delayed(delay);
    if (key == failReadsOf) throw failReadsWith();
    return super.read(key: key, options: options);
  }
}

/// What the darwin plugin throws when the user dismisses the Face ID sheet.
PlatformException iosCancel() =>
    PlatformException(code: 'Unexpected security result code', message: 'User canceled the operation', details: -128);

/// What the Android plugin throws when the biometric prompt ends with [code]
/// (5 cancelled, 10 user cancelled, 13 negative button).
PlatformException androidCancel([int code = 10]) =>
    PlatformException(code: 'Exception encountered', message: 'Biometric authentication error [$code]: Cancelled');
