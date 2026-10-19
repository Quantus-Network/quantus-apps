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

  /// Existence checks of this key throw what [failReadsWith] builds: a store
  /// the OS can no longer open fails before any value is read.
  String? failContainsKeyOf;

  /// Every operation on this key throws what [unavailableWith] builds, entry
  /// or no entry: a store the OS refuses to open.
  String? unavailableKey;
  Object Function() unavailableWith = noDeviceLock;

  /// Reads of this key wait [delay], so an operation in flight can be observed.
  String? delayReadsOf;
  Duration delay = const Duration(milliseconds: 50);

  final Map<String, int> reads = {};

  int readsOf(String key) => reads[key] ?? 0;

  void _open(String key) {
    if (key == unavailableKey) throw unavailableWith();
  }

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) {
    _open(key);
    if (key == failWritesTo) throw Exception('injected write failure for $key');
    return super.write(key: key, value: value, options: options);
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    _open(key);
    reads[key] = readsOf(key) + 1;
    if (key == delayReadsOf) await Future<void>.delayed(delay);
    if (key == failReadsOf) throw failReadsWith();
    return super.read(key: key, options: options);
  }

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) {
    _open(key);
    if (key == failContainsKeyOf) throw failReadsWith();
    return super.containsKey(key: key, options: options);
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) {
    _open(key);
    return super.delete(key: key, options: options);
  }
}

/// What the Android plugin throws on a device without a lock: the protected
/// store's key cannot even be generated.
PlatformException noDeviceLock() => PlatformException(
  code: 'Exception encountered',
  message: 'Secure lock screen must be enabled to create keys requiring user authentication',
);

/// What the Android plugin throws once the OS has invalidated the key, for
/// example after the device lock was removed.
PlatformException keyInvalidated() =>
    PlatformException(code: 'Exception encountered', message: 'KeyPermanentlyInvalidatedException');

/// What the darwin plugin throws when the user dismisses the Face ID sheet.
PlatformException iosCancel() =>
    PlatformException(code: 'Unexpected security result code', message: 'User canceled the operation', details: -128);

/// What the Android plugin throws when the biometric prompt ends with [code]
/// (5 cancelled, 10 user cancelled, 13 negative button).
PlatformException androidCancel([int code = 10]) =>
    PlatformException(code: 'Exception encountered', message: 'Biometric authentication error [$code]: Cancelled');
