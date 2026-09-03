import 'dart:convert';

import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class _FaultInjectingStorage extends TestFlutterSecureStoragePlatform {
  _FaultInjectingStorage() : super({});

  String? failWritesTo;

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) {
    if (key == failWritesTo) throw Exception('injected write failure for $key');
    return super.write(key: key, value: value, options: options);
  }
}

final _accounts = [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late WalletController controller;
  late _FaultInjectingStorage storage;
  final vault = VaultService();

  setUp(() {
    storage = _FaultInjectingStorage();
    FlutterSecureStoragePlatform.instance = storage;
    container = ProviderContainer();
    addTearDown(container.dispose);
    controller = container.read(walletControllerProvider.notifier);
  });

  test('rotates the vault password; the old password stops working', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: false, accounts: _accounts);

    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    expect(result, PasswordChangeResult.changed);

    expect((await vault.unlockWithPassword('beta')).mnemonic, _mnemonic);
    expect(() => vault.unlockWithPassword('alpha'), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('sets a password on a vault created without one', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: '', enableBiometric: false, accounts: _accounts);

    final result = await controller.changePassword(currentPassword: '', newPassword: 'first-real-password');
    expect(result, PasswordChangeResult.changed);
    expect((await vault.unlockWithPassword('first-real-password')).mnemonic, _mnemonic);
  });

  test('wrong current password changes nothing', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: false, accounts: _accounts);

    final result = await controller.changePassword(currentPassword: 'nope', newPassword: 'beta');
    expect(result, PasswordChangeResult.wrongPassword);
    expect((await vault.unlockWithPassword('alpha')).mnemonic, _mnemonic);
  });

  test('re-stores the biometric key under the new password', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: true, accounts: _accounts);
    expect(await vault.isBiometricEnabled(), isTrue);

    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    expect(result, PasswordChangeResult.changed);
    expect(await vault.isBiometricEnabled(), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, _mnemonic);
  });

  test('a failed vault write keeps the old password and biometric unlock intact', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: true, accounts: _accounts);

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

  test('a rotation killed after the vault write disables biometric unlock at the next launch', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: true, accounts: _accounts);
    // The interrupted interval: the new vault is committed but the process
    // died before the biometric key was re-stored or deleted.
    await vault.createVault(
      mnemonic: _mnemonic,
      password: 'beta',
      accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy)],
    );

    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    fresh.read(walletControllerProvider.notifier);
    while (fresh.read(walletControllerProvider).status == WalletStatus.initializing) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(fresh.read(walletControllerProvider).status, WalletStatus.locked);
    expect(fresh.read(walletControllerProvider).biometricEnabled, isFalse);
    expect(storage.data.containsKey('cold_unlock_key'), isFalse);
    expect((await vault.unlockWithPassword('beta')).mnemonic, _mnemonic);
  });

  test('a pre-pairing biometric key keeps working and self-heals once stale', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: true, accounts: _accounts);
    final keyBytes = (await vault.unlockWithPassword('alpha')).keyBytes;
    storage.data['cold_unlock_key'] = base64Encode(keyBytes);

    expect(await vault.isBiometricEnabled(), isTrue);
    expect((await vault.unlockWithBiometricKey()).mnemonic, _mnemonic);

    await vault.createVault(
      mnemonic: _mnemonic,
      password: 'beta',
      accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy)],
    );
    expect(await vault.isBiometricEnabled(), isTrue, reason: 'a bare key carries no pairing to check at startup');
    await expectLater(vault.unlockWithBiometricKey(), throwsA(isA<SecretBoxAuthenticationError>()));
    expect(storage.data.containsKey('cold_unlock_key'), isFalse, reason: 'the failed unlock removes the stale key');
  });

  test('a failed biometric re-store keeps the new password and disables biometric unlock', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: true, accounts: _accounts);

    storage.failWritesTo = 'cold_unlock_key';
    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    storage.failWritesTo = null;

    expect(result, PasswordChangeResult.changedBiometricDisabled);
    expect((await vault.unlockWithPassword('beta')).mnemonic, _mnemonic);
    expect(await vault.isBiometricEnabled(), isFalse);
    expect(container.read(walletControllerProvider).biometricEnabled, isFalse);
  });
}
