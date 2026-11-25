import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/utils/send_strategies.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/send/multisig_propose_strategy.dart';

const _main = Account(walletIndex: 0, index: 0, name: 'Main', accountId: 'qzMain');
const _savings = Account(walletIndex: 0, index: 1, name: 'Savings', accountId: 'qzSavings');
const _vault = Account(
  walletIndex: 1,
  index: 0,
  name: 'Vault',
  accountId: 'qzVault',
  accountType: AccountType.keystone,
);
const _watched = Account(
  walletIndex: 2,
  index: 0,
  name: 'Watched',
  accountId: 'qzWatched',
  accountType: AccountType.external,
);

MultisigAccount _multisig(List<String> signers, {required String member}) => MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: signers,
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: member,
);

void main() {
  group('proposersFor', () {
    test('lists the member first, then its other signers here in the wallet\'s order', () {
      final multisig = _multisig(['qzVault', 'qzOther', 'qzSavings', 'qzMain'], member: 'qzSavings');

      expect(proposersFor(multisig, const [_main, _savings, _vault]).map((a) => a.accountId), [
        'qzSavings',
        'qzMain',
        'qzVault',
      ]);
    });

    test('leaves out an account that is no signer, and a signer whose key is not here', () {
      final multisig = _multisig(['qzMain', 'qzWatched'], member: 'qzMain');

      expect(proposersFor(multisig, const [_main, _savings, _watched]), [_main]);
    });
  });

  group('sendStrategyFor a multisig', () {
    test('with its member gone, proposes as another signer here', () {
      final multisig = _multisig(['qzGone', 'qzSavings'], member: 'qzGone');

      final strategy = sendStrategyFor(MultisigDisplayAccount(multisig), accounts: const [_main, _savings]);

      expect((strategy! as MultisigProposeStrategy).proposerId, 'qzSavings');
      expect(sendSigner(strategy, const [_main, _savings]), _savings);
    });

    test('with no signer here whose key is here, offers no proposal', () {
      final multisig = _multisig(['qzGone', 'qzWatched'], member: 'qzGone');

      expect(sendStrategyFor(MultisigDisplayAccount(multisig), accounts: const [_main, _watched]), isNull);
    });
  });
}
