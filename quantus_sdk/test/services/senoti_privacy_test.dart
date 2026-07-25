import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('SenotiService.notifiableAddresses', () {
    const regular = Account(walletIndex: 0, index: 0, name: 'Regular', accountId: 'qzRegular');
    const encrypted = Account(
      walletIndex: 0,
      index: AppConstants.encryptedAccountIndex,
      name: 'Wormhole',
      accountId: 'qzWormhole',
      accountType: AccountType.encrypted,
    );
    const keystone = Account(
      walletIndex: 1,
      index: 0,
      name: 'Hardware',
      accountId: 'qzKeystone',
      accountType: AccountType.keystone,
    );
    final multisig = MultisigAccount(
      name: 'Multisig',
      accountId: 'qzMultisig',
      signers: const ['qzRegular'],
      threshold: 1,
      nonce: BigInt.zero,
      myMemberAccountId: 'qzRegular',
    );

    test('excludes encrypted accounts and keeps regular, keystone and multisig addresses', () {
      final addresses = SenotiService.notifiableAddresses([regular, encrypted, keystone], [multisig]);

      expect(addresses, ['qzRegular', 'qzKeystone', 'qzMultisig']);
    });
  });
}
