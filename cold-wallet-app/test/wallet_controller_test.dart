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
}
