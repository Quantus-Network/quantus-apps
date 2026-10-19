import 'dart:convert';

import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

import 'fakes/fault_injecting_storage.dart';
import 'fakes/wallet_fakes.dart';

/// The device key entry: which store it lands in, the read-back check, and
/// how the OS prompt's outcomes surface.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FaultInjectingStorage storage;
  late VaultService vault;

  setUp(() {
    storage = FaultInjectingStorage();
    FlutterSecureStoragePlatform.instance = storage;
    vault = VaultService();
  });

  Future<List<int>> createVault() async {
    await vault.createVault(mnemonic: testMnemonic, password: 'alpha', accounts: testAccounts);
    return (await vault.unlockWithPassword('alpha')).keyBytes;
  }

  test('a protected key lands in the protected entry only and is read back once', () async {
    final keyBytes = await createVault();

    await vault.storeBiometricKey(keyBytes, protected: true);

    expect(storage.data.containsKey(protectedKeyEntry), isTrue);
    expect(storage.data.containsKey(plainKeyEntry), isFalse);
    expect(storage.readsOf(protectedKeyEntry), 1);
    expect(await vault.isBiometricEnabled(), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, testMnemonic);
  });

  test('a plain key lands in the plain entry only', () async {
    final keyBytes = await createVault();

    await vault.storeBiometricKey(keyBytes, protected: false);

    expect(storage.data.containsKey(plainKeyEntry), isTrue);
    expect(storage.data.containsKey(protectedKeyEntry), isFalse);
    expect(await vault.plainKeyKind(), PlainKeyKind.accepted);
    expect(await vault.isBiometricEnabled(), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, testMnemonic);
  });

  test('moving the key behind user presence removes the plain entry', () async {
    final keyBytes = await createVault();
    await vault.storeBiometricKey(keyBytes, protected: false);

    await vault.storeBiometricKey(keyBytes, protected: true);

    expect(storage.data.containsKey(plainKeyEntry), isFalse);
    expect(storage.data.containsKey(protectedKeyEntry), isTrue);
  });

  test('a cancelled read-back leaves no protected entry and keeps the plain one', () async {
    final keyBytes = await createVault();
    await vault.storeBiometricKey(keyBytes, protected: false);
    storage.failReadsOf = protectedKeyEntry;
    storage.failReadsWith = iosCancel;

    await expectLater(vault.storeBiometricKey(keyBytes, protected: true), throwsA(isA<VaultAccessCancelled>()));

    expect(storage.data.containsKey(protectedKeyEntry), isFalse);
    expect(storage.data.containsKey(plainKeyEntry), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, testMnemonic);
  });

  test('a protected store error at read-back is rethrown as is', () async {
    final keyBytes = await createVault();
    storage.failReadsOf = protectedKeyEntry;
    storage.failReadsWith = () => PlatformException(code: 'Exception encountered', message: 'Keystore broken');

    await expectLater(vault.storeBiometricKey(keyBytes, protected: true), throwsA(isA<PlatformException>()));
  });

  test('reads try the plain entry first and never touch the protected store', () async {
    final keyBytes = await createVault();
    await vault.storeBiometricKey(keyBytes, protected: true);
    await vault.storeBiometricKey(keyBytes, protected: false);
    storage.reads.clear();

    expect((await vault.unlockWithBiometricKey()).mnemonic, testMnemonic);
    expect(await vault.isBiometricEnabled(), isTrue);

    expect(storage.readsOf(protectedKeyEntry), 0);
  });

  test('checking for the protected entry never reads its value', () async {
    await vault.storeBiometricKey(await createVault(), protected: true);
    storage.reads.clear();

    expect(await vault.hasProtectedKey(), isTrue);
    expect(storage.readsOf(protectedKeyEntry), 0);
  });

  group('prompt outcomes', () {
    setUp(() async {
      await vault.storeBiometricKey(await createVault(), protected: true);
      storage.failReadsOf = protectedKeyEntry;
    });

    test('iOS cancel', () async {
      storage.failReadsWith = iosCancel;
      await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<VaultAccessCancelled>()));
    });

    for (final code in [5, 10, 13]) {
      test('Android error [$code]', () async {
        storage.failReadsWith = () => androidCancel(code);
        await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<VaultAccessCancelled>()));
      });
    }

    test('any other platform error is rethrown', () async {
      storage.failReadsWith = () => androidCancel(7);
      await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<PlatformException>()));
    });

    test('the prompt counter drops back after a failure', () async {
      storage.failReadsWith = iosCancel;
      await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<VaultAccessCancelled>()));
      expect(vault.promptInProgress, isFalse);
    });
  });

  test('promptInProgress is true only while the protected store is in use', () async {
    await vault.storeBiometricKey(await createVault(), protected: true);
    storage.delayReadsOf = protectedKeyEntry;

    expect(vault.promptInProgress, isFalse);
    final unlock = vault.unlockWithBiometricKey();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(vault.promptInProgress, isTrue);
    await unlock;
    expect(vault.promptInProgress, isFalse);
  });

  test('a pre-pairing plain key keeps working and is removed once stale', () async {
    final keyBytes = await createVault();
    storage.data[plainKeyEntry] = base64Encode(keyBytes);

    expect(await vault.plainKeyKind(), PlainKeyKind.legacy);
    expect((await vault.unlockWithBiometricKey()).mnemonic, testMnemonic);

    await vault.createVault(mnemonic: testMnemonic, password: 'beta', accounts: testAccounts);
    expect(await vault.isBiometricEnabled(), isTrue, reason: 'a bare key carries no pairing to check at startup');
    await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<SecretBoxAuthenticationError>()));
    expect(storage.data.containsKey(plainKeyEntry), isFalse, reason: 'the failed unlock removes the stale key');
  });

  test('a protected key for a previous vault is removed when it fails to unlock', () async {
    await vault.storeBiometricKey(await createVault(), protected: true);
    await vault.createVault(mnemonic: testMnemonic, password: 'beta', accounts: testAccounts);

    await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<SecretBoxAuthenticationError>()));

    expect(storage.data.containsKey(protectedKeyEntry), isFalse);
    expect(await vault.isBiometricEnabled(), isFalse);
  });

  test('discarding an incomplete vault removes it even when the protected store cancels', () async {
    final keyBytes = await createVault();
    await vault.storeBiometricKey(keyBytes, protected: true);
    await vault.storeBiometricKey(keyBytes, protected: false);
    storage.unavailableKey = protectedKeyEntry;
    storage.unavailableWith = androidCancel;

    await vault.discardIncompleteVault();

    expect(storage.data.containsKey(vaultEntry), isFalse);
    expect(storage.data.containsKey(plainKeyEntry), isFalse);
    expect(storage.data.containsKey(protectedKeyEntry), isTrue, reason: 'left for the next creation to overwrite');
  });

  test('a cancelled wipe keeps the vault', () async {
    await vault.storeBiometricKey(await createVault(), protected: true);
    storage.unavailableKey = protectedKeyEntry;
    storage.unavailableWith = androidCancel;

    await expectLater(vault.wipe(), throwsA(isA<VaultAccessCancelled>()));

    expect(storage.data.containsKey(vaultEntry), isTrue);
  });

  test('wipe removes the vault, the backup and both key entries', () async {
    final keyBytes = await createVault();
    await vault.storeBiometricKey(keyBytes, protected: true);
    await vault.storeBiometricKey(keyBytes, protected: false);
    await vault.backupVaultForMigration();

    await vault.wipe();

    expect(storage.data, isEmpty);
  });
}
