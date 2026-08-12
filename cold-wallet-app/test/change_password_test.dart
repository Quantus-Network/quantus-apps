import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late WalletController controller;
  final vault = VaultService();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
    controller = container.read(walletControllerProvider.notifier);
  });

  test('rotates the vault password; the old password stops working', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: false);

    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    expect(result, PasswordChangeResult.changed);

    expect((await vault.unlockWithPassword('beta')).mnemonic, _mnemonic);
    expect(() => vault.unlockWithPassword('alpha'), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('sets a password on a vault created without one', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: '', enableBiometric: false);

    final result = await controller.changePassword(currentPassword: '', newPassword: 'first-real-password');
    expect(result, PasswordChangeResult.changed);
    expect((await vault.unlockWithPassword('first-real-password')).mnemonic, _mnemonic);
  });

  test('wrong current password changes nothing', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: false);

    final result = await controller.changePassword(currentPassword: 'nope', newPassword: 'beta');
    expect(result, PasswordChangeResult.wrongPassword);
    expect((await vault.unlockWithPassword('alpha')).mnemonic, _mnemonic);
  });

  test('re-stores the biometric key under the new password', () async {
    await controller.createWallet(mnemonic: _mnemonic, password: 'alpha', enableBiometric: true);
    expect(await vault.isBiometricEnabled(), isTrue);

    final result = await controller.changePassword(currentPassword: 'alpha', newPassword: 'beta');
    expect(result, PasswordChangeResult.changed);
    expect(await vault.isBiometricEnabled(), isTrue);
    expect(await vault.unlockWithBiometricKey(), _mnemonic);
  });
}
