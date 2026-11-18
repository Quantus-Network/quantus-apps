import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/send/encrypted_send_strategy.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../fakes.dart';

WormholeUtxo _utxo(int scaled) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: 't$scaled',
    blockHeight: 1,
    timestamp: DateTime(2026),
    fromId: 'from',
    toId: 'to',
    amount: wormholeTokenFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
    extrinsicId: '',
    viaWormhole: false,
  ),
  owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: '0x00'),
  nullifierHex: '0xn$scaled',
);

void main() {
  final account = makeAccount(1, accountType: AccountType.encrypted);
  final recipient = makeAccount(2);
  final tenTokens = wormholeTokenFromScaled(1000);
  final feeToken = wormholeTokenFromScaled(1);
  // One input, so the send makes one deposit and nothing is looked up.
  final plan = WormholeSpendPlan(
    batches: [
      [WormholeLeafAssignment(utxo: _utxo(1001), recipientScaled: 1000, changeScaled: 0)],
    ],
    amountToken: tenTokens,
    changeToken: BigInt.zero,
    feeToken: feeToken,
  );
  late WalletTestBed bed;

  setUp(() => bed = WalletTestBed());

  Future<SendOutcome> submit(WidgetRef ref) => EncryptedSendStrategy(account: account).submit(
    ref,
    recipientAddress: recipient.accountId,
    amount: tenTokens,
    fee: EncryptedFee(plan: plan),
    isPayMode: false,
  );

  group('submit', () {
    testWidgets('asks for approval with the send\'s reason, then hands the plan over to be proved', (tester) async {
      final ref = await pumpRef(tester, overrides: bed.overrides);

      final outcome = await submit(ref) as SendNeedsProving;

      expect(bed.userApproval.reasons, [ref.read(l10nProvider).sendReviewAuthReason]);
      expect(outcome.plan, same(plan));
      expect(outcome.amount, tenTokens);
      expect(outcome.account, account);
    });

    for (final refusal in [ApprovalResult.declined, ApprovalResult.notSetUp]) {
      testWidgets('an approval that is ${refusal.name} hands nothing over and says authentication is required', (
        tester,
      ) async {
        bed.userApproval.answer = () async => refusal;
        final ref = await pumpRef(tester, overrides: bed.overrides);

        final outcome = await submit(ref);

        expect((outcome as SendFailed).message, ref.read(l10nProvider).sendReviewAuthRequired);
      });
    }
  });

  testWidgets('reviewRows are the recipient, the amount, the encrypted send\'s fee and their sum', (tester) async {
    final read = await pumpWatched(
      tester,
      overrides: bed.overrides,
      build: (ref) => EncryptedSendStrategy(account: account).reviewRows(
        ref,
        recipientAddress: ' ${recipient.accountId} ',
        amount: tenTokens,
        fee: EncryptedFee(plan: plan),
      ),
    );

    final l10n = lookupAppLocalizations(const Locale('en'));
    const symbol = AppConstants.tokenSymbol;
    expect(read(), [
      SendReviewText(l10n.sendReviewTo, recipient.accountId),
      SendReviewText(l10n.sendReviewAmount, '10 $symbol'),
      SendReviewText(l10n.encryptedSendFeeLabel, '0.01 $symbol'),
      SendReviewText(l10n.sendReviewYouPay, '10.01 $symbol'),
    ]);
  });
}
