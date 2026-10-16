import 'dart:convert';

import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

import 'fakes/fault_injecting_storage.dart';
import 'fakes/wallet_fakes.dart';

const _mnemonic = testMnemonic;

final _accounts = [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)];

/// The password rotation is still the commit step of the legacy migration, so
/// it is exercised on vaults created under a known password, with the key
/// entry in the plain store where the tests can inspect it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late WalletController controller;
  late FaultInjectingStorage storage;
  final vault = VaultService();

  setUp(() {
    storage = FaultInjectingStorage();
    FlutterSecureStoragePlatform.instance = storage;
  });

  Future<void> createWallet({required String password, required bool biometric}) async {
    await vault.createVault(mnemonic: _mnemonic, password: password, accounts: _accounts);
    if (biometric) await vault.storeBiometricKey((await vault.unlockWithPassword(password)).keyBytes, protected: false);
    container = ProviderContainer(
      overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth(canProtect: false))],
    );
    addTearDown(container.dispose);
    controller = container.read(walletControllerProvider.notifier);
    await awaitInit(container);
  }

  test('rotates the vault password; the old password stops working', () async {
    await createWallet(password: 'alpha', biometric: false);

    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    expect(result, PasswordChangeResult.changed);

    expect((await vault.unlockWithPassword('beta')).mnemonic, _mnemonic);
    expect(() => vault.unlockWithPassword('alpha'), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('sets a password on a vault created without one', () async {
    await createWallet(password: '', biometric: false);

    final result = await controller.changePassword(currentPassword: '', newPassword: 'first-real-password');
    expect(result, PasswordChangeResult.changed);
    expect((await vault.unlockWithPassword('first-real-password')).mnemonic, _mnemonic);
  });

  test('wrong current password changes nothing', () async {
    await createWallet(password: 'alpha', biometric: false);

    final result = await controller.changePassword(currentPassword: 'nope', newPassword: 'beta');
    expect(result, PasswordChangeResult.wrongPassword);
    expect((await vault.unlockWithPassword('alpha')).mnemonic, _mnemonic);
  });

  test('re-stores the biometric key under the new password', () async {
    await createWallet(password: 'alpha', biometric: true);
    expect(await vault.isBiometricEnabled(), isTrue);

    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    expect(result, PasswordChangeResult.changed);
    expect(await vault.isBiometricEnabled(), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, _mnemonic);
  });

  test('a failed vault write keeps the old password and biometric unlock intact', () async {
    await createWallet(password: 'alpha', biometric: true);

    storage.failWritesTo = 'cold_vault';
    await expectLater(
      controller.changePassword(currentPassword: 'alpha', newPassword: 'beta'),
      throwsA(isA<Exception>()),
    );
    storage.failWritesTo = null;

    expect((await vault.unlockWithPassword('alpha')).mnemonic, _mnemonic);
    expect(await vault.isBiometricEnabled(), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, _mnemonic);
    expect(container.read(walletControllerProvider).biometricEnabled, isTrue);
  });

  test('a rotation killed after the vault write leaves a password wallet at the next launch', () async {
    await createWallet(password: 'alpha', biometric: true);
    // The interrupted interval: the new vault is committed but the process
    // died before the biometric key was re-stored or deleted.
    await vault.createVault(
      mnemonic: _mnemonic,
      password: 'beta',
      accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)],
    );

    final fresh = ProviderContainer(overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth())]);
    addTearDown(fresh.dispose);
    fresh.read(walletControllerProvider.notifier);
    await awaitInit(fresh);

    // No key entry can open the new vault, so it is a password wallet again.
    expect(fresh.read(walletControllerProvider).status, WalletStatus.needsMigration);
    expect(fresh.read(walletControllerProvider).biometricEnabled, isFalse);
    expect(storage.data.containsKey('cold_unlock_key'), isFalse);
    expect((await vault.unlockWithPassword('beta')).mnemonic, _mnemonic);
  });

  test('a pre-pairing biometric key keeps working and self-heals once stale', () async {
    await createWallet(password: 'alpha', biometric: true);
    final keyBytes = (await vault.unlockWithPassword('alpha')).keyBytes;
    storage.data['cold_unlock_key'] = base64Encode(keyBytes);

    expect(await vault.isBiometricEnabled(), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, _mnemonic);

    await vault.createVault(
      mnemonic: _mnemonic,
      password: 'beta',
      accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)],
    );
    expect(await vault.isBiometricEnabled(), isTrue, reason: 'a bare key carries no pairing to check at startup');
    await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<SecretBoxAuthenticationError>()));
    expect(storage.data.containsKey('cold_unlock_key'), isFalse, reason: 'the failed unlock removes the stale key');
  });

  test('a failed biometric re-store keeps the new password and disables biometric unlock', () async {
    await createWallet(password: 'alpha', biometric: true);

    storage.failWritesTo = 'cold_unlock_key';
    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    storage.failWritesTo = null;

    expect(result, PasswordChangeResult.changedBiometricDisabled);
    expect((await vault.unlockWithPassword('beta')).mnemonic, _mnemonic);
    expect(await vault.isBiometricEnabled(), isFalse);
    expect(container.read(walletControllerProvider).biometricEnabled, isFalse);
  });
}
