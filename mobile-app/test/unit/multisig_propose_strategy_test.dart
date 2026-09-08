import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/multisig_propose_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

import '../fakes.dart';

void main() {
  final keystone = makeAccount(3, accountType: AccountType.keystone);
  final other = makeAccount(2);
  final msig = MultisigAccount(
    name: 'Msig',
    accountId: 'qzmsig${'x' * 40}',
    signers: [keystone.accountId, other.accountId],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: keystone.accountId,
  );
  final fee = ProposeFee(
    ProposeFeeBreakdown(
      networkFee: BigInt.from(10),
      deposit: BigInt.from(20),
      creationFee: BigInt.from(30),
      expiryBlock: 1000,
    ),
  );

  Future<SendOutcome> submit(WidgetTester tester, List<Account> accounts) async {
    final ref = await pumpRef(
      tester,
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService()),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: accounts)),
      ],
    );
    return MultisigProposeStrategy(msig: msig).submit(
      ref,
      recipientAddress: other.accountId,
      recipientChecksum: 'checksum',
      amount: BigInt.from(1000),
      fee: fee,
      isPayMode: false,
    );
  }

  testWidgets('a keystone member is handed to the signing session instead of signing locally', (tester) async {
    final outcome = await submit(tester, [keystone, other]);

    expect(outcome, isA<SendNeedsHardwareSignature>());
    final hardware = outcome as SendNeedsHardwareSignature;
    expect(hardware.session.account.accountId, keystone.accountId);
    expect(hardware.terminalForHash('0xabc').explorerUrl, isNull);
  });

  testWidgets('fails before signing when the member account is not in the wallet', (tester) async {
    expect(await submit(tester, [other]), isA<SendFailed>());
  });
}
