import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/receive_address.dart';

/// Hands out [nextAddress] as the next unused deposit address.
class _FakeEncryptedAccountService extends Fake implements EncryptedAccountService {
  _FakeEncryptedAccountService(this.nextAddress);

  final String nextAddress;

  @override
  Future<WormholeKeyPair> receiveKeyPair() async =>
      WormholeKeyPair(address: nextAddress, addressHex: '', rewardsPreimageHex: '', secretHex: '');
}

/// Fails the test if anything asks it for a deposit address.
class _UnusedEncryptedAccountService extends Fake implements EncryptedAccountService {
  @override
  Future<WormholeKeyPair> receiveKeyPair() => fail('a transparent account has no deposit address to derive');
}

void main() {
  test('a transparent account receives at its own address', () async {
    final container = ProviderContainer(
      overrides: [encryptedAccountServiceProvider(0).overrideWithValue(_UnusedEncryptedAccountService())],
    );
    addTearDown(container.dispose);
    const account = Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'qzMain');

    expect(await receiveAddress(container.read, account), 'qzMain');
  });

  test("an encrypted account receives at its wallet's next unused deposit address", () async {
    final container = ProviderContainer(
      overrides: [
        encryptedAccountServiceProvider(0).overrideWithValue(_UnusedEncryptedAccountService()),
        encryptedAccountServiceProvider(1).overrideWithValue(_FakeEncryptedAccountService('qzDeposit7')),
      ],
    );
    addTearDown(container.dispose);
    const account = Account(
      walletIndex: 1,
      index: AppConstants.encryptedAccountIndex,
      name: 'Encrypted Account',
      accountId: 'qzEncrypted1',
      accountType: AccountType.encrypted,
    );

    expect(await receiveAddress(container.read, account), 'qzDeposit7');
  });
}
