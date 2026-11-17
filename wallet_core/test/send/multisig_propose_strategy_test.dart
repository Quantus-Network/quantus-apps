import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/send/multisig_propose_strategy.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

import '../fakes.dart';

/// The chain at block 100, where any block is reached at the start of 2026.
class _FakeMultisigService extends Fake implements MultisigService {
  @override
  Future<int> currentBlockNumber() async => 100;

  @override
  DateTime blockToTime(int targetBlock, int currentBlock) => DateTime.utc(2026);
}

void main() {
  final member = makeAccount(1);
  final other = makeAccount(2);
  final recipient = makeAccount(3);
  final oneToken = NumberFormattingService.scaleFactorBigInt;
  final msig = MultisigAccount(
    name: 'Msig',
    accountId: 'qzmsig${'x' * 40}',
    signers: [member.accountId, other.accountId],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: member.accountId,
  );
  final fee = ProposeFee(
    ProposeFeeBreakdown(networkFee: oneToken, deposit: BigInt.two * oneToken, creationFee: oneToken, expiryBlock: 1000),
  );
  late WalletTestBed bed;
  late FakeTransactionSubmissionService submission;

  setUp(() async {
    // A submitted proposal records its recipient among the recent addresses.
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
    bed = WalletTestBed();
    submission = FakeTransactionSubmissionService();
  });

  List<Override> overrides() => [
    ...bed.overrides,
    accountsProvider.overrideWith((ref) => AccountsNotifier(bed.accounts, initialAccounts: [member])),
    multisigServiceProvider.overrideWithValue(_FakeMultisigService()),
    transactionSubmissionServiceProvider.overrideWithValue(submission),
  ];

  Future<SendOutcome> submit(WidgetRef ref) => MultisigProposeStrategy(
    msig: msig,
  ).submit(ref, recipientAddress: recipient.accountId, amount: BigInt.from(5) * oneToken, fee: fee, isPayMode: false);

  group('submit', () {
    testWidgets('asks for approval with the proposal\'s reason, then submits the proposal', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());

      final outcome = await submit(ref);

      expect(outcome, isA<SendSubmitted>());
      expect(bed.userApproval.reasons, [ref.read(l10nProvider).multisigProposeAuthReason]);
      expect(submission.proposals, [(recipient.accountId, BigInt.from(5) * oneToken, 1000)]);
    });

    for (final refusal in [ApprovalResult.declined, ApprovalResult.notSetUp]) {
      testWidgets('an approval that is ${refusal.name} proposes nothing and says authentication is required', (
        tester,
      ) async {
        bed.userApproval.answer = () async => refusal;
        final ref = await pumpRef(tester, overrides: overrides());

        final outcome = await submit(ref);

        expect((outcome as SendFailed).message, ref.read(l10nProvider).multisigProposeAuthRequired);
        expect(submission.proposals, isEmpty);
      });
    }
  });

  testWidgets('reviewRows name the proposer by address, and give the expiry a time once the block is known', (
    tester,
  ) async {
    final read = await pumpWatched(
      tester,
      overrides: overrides(),
      build: (ref) => MultisigProposeStrategy(
        msig: msig,
      ).reviewRows(ref, recipientAddress: recipient.accountId, amount: BigInt.from(5) * oneToken, fee: fee),
    );

    final l10n = lookupAppLocalizations(const Locale('en'));
    const symbol = AppConstants.tokenSymbol;
    List<SendReviewRow> rowsWith(MultisigExpiryParts expiry) => [
      SendReviewAddress(l10n.multisigProposeProposerLabel, member.accountId),
      SendReviewText(l10n.sendReviewAmount, '5 $symbol'),
      SendReviewText(l10n.multisigProposeThresholdLabel, '2/2'),
      SendReviewExpiry(l10n.multisigProposeExpiresLabel, expiry),
      SendReviewText(l10n.sendReviewNetworkFee, '1 $symbol'),
      SendReviewText(l10n.multisigProposalDepositLabel, '2 $symbol'),
      SendReviewText(l10n.multisigProposeFeeRowLabel, '1 $symbol'),
      SendReviewText(l10n.multisigProposeMemberTotalLabel, '4 $symbol'),
    ];
    final block = l10n.multisigExpiresBlockOnly(1000);

    expect(read(), rowsWith(MultisigExpiryParts(blockLabel: block)));

    // The current block arrives.
    await tester.pump();
    expect(
      read(),
      rowsWith(
        MultisigExpiryParts(
          blockLabel: block,
          estimatedDateTime: '~${DatetimeFormattingService.formatTxDateTime(DateTime.utc(2026))}',
        ),
      ),
    );
  });
}
