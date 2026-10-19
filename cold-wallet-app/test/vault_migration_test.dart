import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

import 'fakes/fault_injecting_storage.dart';
import 'fakes/wallet_fakes.dart';

/// A wallet created with an app password moves behind the device key. The
/// seed must never be in fewer than one decryptable copy, whatever fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FaultInjectingStorage storage;
  final vault = VaultService();

  setUp(() {
    storage = FaultInjectingStorage();
    FlutterSecureStoragePlatform.instance = storage;
  });

  Future<void> legacyVault() => vault.createVault(mnemonic: testMnemonic, password: 'alpha', accounts: testAccounts);

  Future<(ProviderContainer, WalletController)> boot({bool canProtect = true, bool storePromptsOnce = false}) async {
    final container = ProviderContainer(
      overrides: [
        coldAuthServiceProvider.overrideWithValue(
          FakeColdAuth(canProtect: canProtect, storePromptsOnce: storePromptsOnce),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(walletControllerProvider.notifier);
    await awaitInit(container);
    return (container, controller);
  }

  WalletStatus statusOf(ProviderContainer c) => c.read(walletControllerProvider).status;

  void expectPasswordVaultIntact() {
    expect(storage.data.containsKey(vaultBackupEntry), isFalse);
    expect(storage.data.containsKey(plainKeyEntry), isFalse);
    expect(storage.data.containsKey(protectedKeyEntry), isFalse);
  }

  test('a password wallet starts in needsMigration', () async {
    await legacyVault();
    final (container, _) = await boot();
    expect(statusOf(container), WalletStatus.needsMigration);
  });

  test('migration moves the vault behind the device key and unlocks', () async {
    await legacyVault();
    final (container, controller) = await boot();

    expect(await controller.migrateLegacy('alpha'), isTrue);

    final state = container.read(walletControllerProvider);
    expect(state.status, WalletStatus.unlocked);
    expect(state.mnemonic, testMnemonic);
    expect(state.biometricEnabled, isTrue);
    expect(storage.data.containsKey(protectedKeyEntry), isTrue);
    expect(storage.data.containsKey(plainKeyEntry), isFalse);
    expect(storage.data.containsKey(vaultBackupEntry), isFalse);
    await expectLater(vault.unlockWithPassword('alpha'), throwsA(isA<SecretBoxAuthenticationError>()));

    final (relaunched, again) = await boot();
    expect(statusOf(relaunched), WalletStatus.locked);
    expect(await again.unlockWithBiometric(), isTrue);
    expect(relaunched.read(walletControllerProvider).mnemonic, testMnemonic);
  });

  test('a device without a lock migrates to the plain entry', () async {
    await legacyVault();
    final (_, controller) = await boot(canProtect: false);

    expect(await controller.migrateLegacy('alpha'), isTrue);

    expect(storage.data.containsKey(plainKeyEntry), isTrue);
    expect(storage.data.containsKey(protectedKeyEntry), isFalse);
  });

  test('a wrong password changes nothing', () async {
    await legacyVault();
    final (container, controller) = await boot();
    final before = Map.of(storage.data);

    expect(await controller.migrateLegacy('nope'), isFalse);

    expect(storage.data, before);
    expect(statusOf(container), WalletStatus.needsMigration);
  });

  test('a key store fault after the rotation restores the password vault', () async {
    await legacyVault();
    final (container, controller) = await boot();
    storage.failWritesTo = protectedKeyEntry;

    await expectLater(controller.migrateLegacy('alpha'), throwsA(isA<Exception>()));

    expectPasswordVaultIntact();
    expect((await vault.unlockWithPassword('alpha')).mnemonic, testMnemonic);
    expect(statusOf(container), WalletStatus.needsMigration);

    storage.failWritesTo = null;
    expect(await controller.migrateLegacy('alpha'), isTrue, reason: 'the same password finishes the move');
  });

  test('a cancelled prompt at read-back restores the password vault', () async {
    await legacyVault();
    final (container, controller) = await boot();
    storage.failReadsOf = protectedKeyEntry;
    storage.failReadsWith = iosCancel;

    await expectLater(controller.migrateLegacy('alpha'), throwsA(isA<VaultAccessCancelled>()));

    expectPasswordVaultIntact();
    expect((await vault.unlockWithPassword('alpha')).mnemonic, testMnemonic);
    expect(statusOf(container), WalletStatus.needsMigration);
  });

  test('a kill between the vault write and the key write is undone at the next launch', () async {
    await legacyVault();
    // The interrupted interval: the backup exists, the vault is under the
    // internal secret, no key entry was written.
    await vault.backupVaultForMigration();
    await vault.createVault(mnemonic: testMnemonic, password: VaultService.randomSecret(), accounts: testAccounts);
    await expectLater(vault.unlockWithPassword('alpha'), throwsA(isA<SecretBoxAuthenticationError>()));

    final (relaunched, _) = await boot();

    expect(statusOf(relaunched), WalletStatus.needsMigration);
    expectPasswordVaultIntact();
    expect((await vault.unlockWithPassword('alpha')).mnemonic, testMnemonic);
  });

  test('a plain key orphaned by a rotation that died before its re-store is dropped at the next launch', () async {
    await legacyVault();
    await vault.storeBiometricKey((await vault.unlockWithPassword('alpha')).keyBytes, protected: false);
    await vault.createVault(mnemonic: testMnemonic, password: 'beta', accounts: testAccounts);

    final (container, _) = await boot(canProtect: false);

    expect(statusOf(container), WalletStatus.needsMigration);
    expect(container.read(walletControllerProvider).biometricEnabled, isFalse);
    expect(storage.data.containsKey(plainKeyEntry), isFalse);
    expect((await vault.unlockWithPassword('beta')).mnemonic, testMnemonic);
  });

  group('Android without a device lock', () {
    // The protected store cannot be opened there, entry or no entry.
    setUp(() => storage.unavailableKey = protectedKeyEntry);

    Future<(ProviderContainer, WalletController)> bootAndroid() => boot(canProtect: false, storePromptsOnce: true);

    test('a password wallet reaches migration without the protected store', () async {
      await legacyVault();
      final (container, _) = await bootAndroid();
      expect(statusOf(container), WalletStatus.needsMigration);
    });

    test('migrates to the plain entry and opens from it at the next launch', () async {
      await legacyVault();
      final (container, controller) = await bootAndroid();

      expect(await controller.migrateLegacy('alpha'), isTrue);

      expect(statusOf(container), WalletStatus.unlocked);
      expect(container.read(walletControllerProvider).mnemonic, testMnemonic);
      expect(storage.data.containsKey(plainKeyEntry), isTrue);
      expect(storage.data.containsKey(vaultBackupEntry), isFalse);
      await expectLater(vault.unlockWithPassword('alpha'), throwsA(isA<SecretBoxAuthenticationError>()));

      final (relaunched, again) = await bootAndroid();
      expect(statusOf(relaunched), WalletStatus.locked);
      expect(await again.unlockWithBiometric(), isTrue);
      expect(relaunched.read(walletControllerProvider).mnemonic, testMnemonic);
      expect(await again.confirmPresence(), isTrue);
    });

    test('a wrong password changes nothing', () async {
      await legacyVault();
      final (container, controller) = await bootAndroid();
      final before = Map.of(storage.data);

      expect(await controller.migrateLegacy('nope'), isFalse);

      expect(storage.data, before);
      expect(statusOf(container), WalletStatus.needsMigration);
    });
  });

  group('a plain key on a device that can protect', () {
    Future<WalletController> plainWalletRelaunched() async {
      final (_, created) = await boot(canProtect: false);
      await created.createWallet(mnemonic: testMnemonic, accounts: testAccounts, protected: false);
      final (relaunched, controller) = await boot();
      expect(statusOf(relaunched), WalletStatus.locked);
      return controller;
    }

    test('moves behind user presence at the first unlock', () async {
      final controller = await plainWalletRelaunched();

      expect(await controller.unlockWithBiometric(), isTrue);

      expect(storage.data.containsKey(plainKeyEntry), isFalse);
      expect(storage.data.containsKey(protectedKeyEntry), isTrue);
      expect((await vault.unlockWithBiometricKey()).mnemonic, testMnemonic);
    });

    test('stays plain and locked when the prompt is cancelled', () async {
      final controller = await plainWalletRelaunched();
      storage.failReadsOf = protectedKeyEntry;
      storage.failReadsWith = iosCancel;

      expect(await controller.unlockWithBiometric(), isFalse);

      expect(storage.data.containsKey(plainKeyEntry), isTrue);
      expect(storage.data.containsKey(protectedKeyEntry), isFalse);
      storage.failReadsOf = null;
      expect(await controller.unlockWithBiometric(), isTrue);
      expect(storage.data.containsKey(protectedKeyEntry), isTrue);
    });
  });
}
