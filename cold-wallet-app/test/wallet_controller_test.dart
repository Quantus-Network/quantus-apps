import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

import 'fakes/fault_injecting_storage.dart';
import 'fakes/wallet_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FaultInjectingStorage storage;
  late ProviderContainer container;
  late WalletController controller;
  final vault = VaultService();

  setUp(() async {
    storage = FaultInjectingStorage();
    FlutterSecureStoragePlatform.instance = storage;
    container = ProviderContainer(overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth())]);
    addTearDown(container.dispose);
    controller = container.read(walletControllerProvider.notifier);
    await awaitInit(container);
  });

  WalletState state() => container.read(walletControllerProvider);

  Future<void> createProtected() =>
      controller.createWallet(mnemonic: testMnemonic, accounts: testAccounts, protected: true);

  /// A new process over the same storage: its own controller and vault.
  Future<(ProviderContainer, WalletController)> fresh(FakeColdAuth auth) async {
    final c = ProviderContainer(overrides: [coldAuthServiceProvider.overrideWithValue(auth)]);
    addTearDown(c.dispose);
    await awaitInit(c);
    return (c, c.read(walletControllerProvider.notifier));
  }

  test('starts in needsSetup without a vault', () {
    expect(state().status, WalletStatus.needsSetup);
  });

  test('createWallet ends unlocked with the device key stored', () async {
    await createProtected();

    expect(state().status, WalletStatus.unlocked);
    expect(state().mnemonic, testMnemonic);
    expect(state().biometricEnabled, isTrue);
    expect(storage.data.containsKey(protectedKeyEntry), isTrue);
  });

  test('a cancelled prompt during creation leaves no vault behind', () async {
    storage.failReadsOf = protectedKeyEntry;
    storage.failReadsWith = iosCancel;

    await expectLater(createProtected(), throwsA(isA<VaultAccessCancelled>()));

    expect(await vault.hasWallet(), isFalse);
    expect(storage.data, isEmpty);
    expect(state().status, WalletStatus.needsSetup);

    storage.failReadsOf = null;
    await createProtected();
    expect(state().status, WalletStatus.unlocked);
  });

  test('a key store fault during creation leaves no vault behind', () async {
    storage.failWritesTo = protectedKeyEntry;

    await expectLater(createProtected(), throwsA(isA<Exception>()));

    expect(storage.data, isEmpty);
    expect(state().status, WalletStatus.needsSetup);
  });

  test('a prompt cancelled at the key write and again at the cleanup leaves no vault behind', () async {
    storage.unavailableKey = protectedKeyEntry;
    storage.unavailableWith = androidCancel;

    await expectLater(createProtected(), throwsA(isA<VaultAccessCancelled>()));

    expect(storage.data, isEmpty);
    expect(state().status, WalletStatus.needsSetup);

    storage.unavailableKey = null;
    await createProtected();
    expect(state().status, WalletStatus.unlocked);
  });

  test('a vault read failure right after its write leaves no vault behind', () async {
    storage.failReadsOf = vaultEntry;

    await expectLater(createProtected(), throwsA(isA<Exception>()));

    storage.failReadsOf = null;
    expect(storage.data, isEmpty);
    expect(await vault.hasWallet(), isFalse);
    expect(state().status, WalletStatus.needsSetup);

    await createProtected();
    expect(state().status, WalletStatus.unlocked);
  });

  test('a cancelled unlock reports it and keeps the wallet locked', () async {
    await createProtected();
    controller.lock();
    storage.failReadsOf = protectedKeyEntry;
    storage.failReadsWith = androidCancel;

    expect(await controller.unlockWithBiometric(), isFalse);
    expect(state().status, WalletStatus.locked);
    expect(state().error, unlockCancelledError);

    storage.failReadsOf = null;
    expect(await controller.unlockWithBiometric(), isTrue);
    expect(state().error, isNull);
  });

  test('a key that no longer opens the vault is reported and reset wipes everything', () async {
    await createProtected();
    controller.lock();
    await vault.createVault(mnemonic: testMnemonic, password: 'other', accounts: testAccounts);

    expect(await controller.unlockWithBiometric(), isFalse);

    expect(state().status, WalletStatus.locked);
    expect(state().biometricEnabled, isFalse);
    expect(state().error, contains('can no longer open'));
    expect(storage.data.containsKey(protectedKeyEntry), isFalse);

    await controller.wipe();
    expect(state().status, WalletStatus.needsSetup);
    expect(storage.data, isEmpty);
  });

  test('an unlock that finds no key entry re-reads the wallet state', () async {
    await createProtected();
    controller.lock();
    storage.data.remove(protectedKeyEntry);

    expect(await controller.unlockWithBiometric(), isFalse);

    expect(state().status, WalletStatus.needsMigration);
  });

  test('confirmPresence compares a fresh read with the session key', () async {
    await createProtected();
    storage.reads.clear();

    expect(await controller.confirmPresence(), isTrue);
    expect(storage.readsOf(protectedKeyEntry), 1);

    storage.failReadsOf = protectedKeyEntry;
    storage.failReadsWith = iosCancel;
    expect(await controller.confirmPresence(), isFalse);
  });

  test('the background re-lock waits for a prompt in flight', () async {
    await createProtected();
    storage.delayReadsOf = protectedKeyEntry;

    final presence = controller.confirmPresence();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.lockOnBackground();
    expect(state().status, WalletStatus.unlocked, reason: 'the OS prompt paused the app, not the user');

    expect(await presence, isTrue);
    controller.lockOnBackground();
    expect(state().status, WalletStatus.locked);
  });

  group('a store that stays authenticated for the process', () {
    test('needs a fresh prompt before every later unlock', () async {
      final auth = FakeColdAuth(storePromptsOnce: true);
      final (c, ctl) = await fresh(auth);
      await ctl.createWallet(mnemonic: testMnemonic, accounts: testAccounts, protected: true);
      ctl.lock();

      auth.promptResult = false;
      final reads = storage.readsOf(protectedKeyEntry);
      expect(await ctl.unlockWithBiometric(), isFalse);
      expect(c.read(walletControllerProvider).status, WalletStatus.locked);
      expect(c.read(walletControllerProvider).error, unlockCancelledError);
      expect(storage.readsOf(protectedKeyEntry), reads, reason: 'a dismissed prompt must not reach the key');

      auth.promptResult = true;
      expect(await ctl.unlockWithBiometric(), isTrue);
      expect(auth.prompts, 2);
    });

    test('lets the store itself prompt for the first unlock of a process', () async {
      await createProtected();
      final auth = FakeColdAuth(storePromptsOnce: true);
      final (c, ctl) = await fresh(auth);

      expect(c.read(walletControllerProvider).status, WalletStatus.locked);
      expect(await ctl.unlockWithBiometric(), isTrue);
      expect(auth.prompts, 0);
    });

    test('needs a fresh prompt to confirm presence', () async {
      final auth = FakeColdAuth(storePromptsOnce: true);
      final (_, ctl) = await fresh(auth);
      await ctl.createWallet(mnemonic: testMnemonic, accounts: testAccounts, protected: true);

      auth.promptResult = false;
      final reads = storage.readsOf(protectedKeyEntry);
      expect(await ctl.confirmPresence(), isFalse);
      expect(storage.readsOf(protectedKeyEntry), reads);

      auth.promptResult = true;
      expect(await ctl.confirmPresence(), isTrue);
    });

    test('is not locked by the pause its own prompt causes', () async {
      final auth = FakeColdAuth(storePromptsOnce: true)..pendingPrompt = Completer<bool>();
      final (c, ctl) = await fresh(auth);
      await ctl.createWallet(mnemonic: testMnemonic, accounts: testAccounts, protected: true);

      final presence = ctl.confirmPresence();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      ctl.lockOnBackground();
      expect(c.read(walletControllerProvider).status, WalletStatus.unlocked);

      auth.pendingPrompt!.complete(true);
      expect(await presence, isTrue);
    });

    test('moves a wallet with no key entry to migration at the first unlock', () async {
      await vault.createVault(mnemonic: testMnemonic, password: 'alpha', accounts: testAccounts);
      final (c, ctl) = await fresh(FakeColdAuth(storePromptsOnce: true));

      expect(c.read(walletControllerProvider).status, WalletStatus.locked);
      expect(await ctl.unlockWithBiometric(), isFalse);
      expect(c.read(walletControllerProvider).status, WalletStatus.needsMigration);
    });
  });

  test('a protected store the OS can no longer open leaves the wallet locked with the reset', () async {
    await createProtected();
    storage.failContainsKeyOf = protectedKeyEntry;
    storage.failReadsOf = protectedKeyEntry;
    storage.failReadsWith = keyInvalidated;
    final (c, ctl) = await fresh(FakeColdAuth());

    expect(c.read(walletControllerProvider).status, WalletStatus.locked);
    expect(c.read(walletControllerProvider).error, contains('can no longer open'));
    expect(await ctl.unlockWithBiometric(), isFalse);
    expect(storage.data.containsKey(vaultEntry), isTrue, reason: 'the vault is kept until the user resets');

    await ctl.wipe();
    expect(c.read(walletControllerProvider).status, WalletStatus.needsSetup);
    expect(storage.data.containsKey(vaultEntry), isFalse);
  });
}
