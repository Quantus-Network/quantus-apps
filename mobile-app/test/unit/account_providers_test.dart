import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';

void main() {
  const account = Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'qzlocal');

  AccountsNotifier seededNotifier() => AccountsNotifier(AccountsService(), initialAccounts: const [account]);

  group('AccountsNotifier.getAccountWithId', () {
    test('returns the matching account', () {
      expect(seededNotifier().getAccountWithId('qzlocal'), same(account));
    });

    test('returns null for an unknown account id', () {
      expect(seededNotifier().getAccountWithId('qzunknown'), isNull);
    });
  });
}
