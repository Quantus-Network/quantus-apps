import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/seed_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

/// One backing map for every store, as on a device where the plugin mock
/// ignores options. Plain and protected entries differ by key.
class _Storage extends TestFlutterSecureStoragePlatform {
  _Storage([Map<String, String>? values]) : super(values ?? {});

  int reads = 0;
  PlatformException? failReadsWith;

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    reads++;
    final failure = failReadsWith;
    if (failure != null) throw failure;
    await Future<void>.delayed(Duration.zero);
    return super.read(key: key, options: options);
  }

  Map<String, String> get values => data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Storage storage;
  late SharedPreferences prefs;

  Future<SeedVault> vault({bool canProtect = true, Map<String, String>? stored}) async {
    storage = _Storage(stored);
    FlutterSecureStoragePlatform.instance = storage;
    SharedPreferences.setMockInitialValues({'keychain_migrated_to_this_device': true});
    prefs = await SharedPreferences.getInstance();
    return SeedVault(prefs, canProtect: () async => canProtect);
  }

  test('stores in the protected store when the device can guard it', () async {
    final v = await vault();
    await v.store(_mnemonic, 0);
    expect(storage.values, {'seed_0': _mnemonic});
    expect(prefs.getString('seed_store_0'), 'protected');
    expect(await v.read(0), _mnemonic);
    expect(await v.exists(0), isTrue);
  });

  test('stores in the plain store on a device without a lock', () async {
    final v = await vault(canProtect: false);
    await v.store(_mnemonic, 1);
    expect(storage.values, {'mnemonic_1': _mnemonic});
    expect(prefs.getString('seed_store_1'), isNull);
    expect(await v.read(1), _mnemonic);
    expect(await v.exists(1), isTrue);
  });

  test('protectStoredSeeds runs beforeMove on the plain phrase, then moves it and is idempotent', () async {
    final v = await vault(stored: {'mnemonic': _mnemonic, 'mnemonic_2': 'other'});
    final moved = <(int, String)>[];
    Future<void> record(int walletIndex, String mnemonic) async {
      expect(storage.values.containsKey(walletIndex == 0 ? 'mnemonic' : 'mnemonic_$walletIndex'), isTrue);
      moved.add((walletIndex, mnemonic));
    }

    await v.protectStoredSeeds([0, 2, 3], beforeMove: record);
    expect(moved, [(0, _mnemonic), (2, 'other')]);
    expect(storage.values, {'seed_0': _mnemonic, 'seed_2': 'other'});
    expect(prefs.getString('seed_store_0'), 'protected');
    expect(prefs.getString('seed_store_2'), 'protected');

    await v.protectStoredSeeds([0, 2, 3], beforeMove: record);
    expect(moved, hasLength(2));
  });

  test('protectStoredSeeds leaves phrases alone when the device cannot guard them', () async {
    final v = await vault(canProtect: false, stored: {'mnemonic': _mnemonic});
    await v.protectStoredSeeds([0], beforeMove: (_, _) async => fail('must not move'));
    expect(storage.values, {'mnemonic': _mnemonic});
    expect(await v.read(0), _mnemonic);
  });

  test('protectStoredSeeds removes a plain copy left by an interrupted move', () async {
    final v = await vault(stored: {'mnemonic': 'stale', 'seed_0': _mnemonic});
    await prefs.setString('seed_store_0', 'protected');
    await v.protectStoredSeeds([0], beforeMove: (_, _) async => fail('already protected'));
    expect(storage.values, {'seed_0': _mnemonic});
  });

  test('delete and deleteAll clear both stores and the records', () async {
    final v = await vault(stored: {'mnemonic_1': 'plain'});
    await v.store(_mnemonic, 0);
    await v.delete(0);
    expect(storage.values, {'mnemonic_1': 'plain'});
    expect(prefs.getString('seed_store_0'), isNull);
    expect(await v.exists(0), isFalse);

    await v.store(_mnemonic, 2);
    await v.deleteAll();
    expect(storage.values, isEmpty);
    expect(prefs.getString('seed_store_2'), isNull);
  });

  test('concurrent reads of one wallet share a single store read', () async {
    final v = await vault();
    await v.store(_mnemonic, 0);
    storage.reads = 0;
    final results = await Future.wait([v.read(0), v.read(0), v.read(0)]);
    expect(results, [_mnemonic, _mnemonic, _mnemonic]);
    expect(storage.reads, 1);
    await v.read(0);
    expect(storage.reads, 2);
  });

  test('a dismissed prompt surfaces as SeedAccessCancelled on either platform', () async {
    final v = await vault();
    await v.store(_mnemonic, 0);
    storage.failReadsWith = PlatformException(code: 'Unexpected security result code', details: -128);
    await expectLater(v.read(0), throwsA(isA<SeedAccessCancelled>()));
    storage.failReadsWith = PlatformException(
      code: 'Exception encountered',
      message: 'Biometric authentication error [10]: Cancelled',
    );
    await expectLater(v.read(0), throwsA(isA<SeedAccessCancelled>()));
    storage.failReadsWith = PlatformException(code: 'Exception encountered', message: 'KeyPermanentlyInvalidated');
    await expectLater(v.read(0), throwsA(isA<PlatformException>()));
  });
}
