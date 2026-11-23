import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../fakes.dart';

void main() {
  final sender = makeAccount(1);
  final recipient = makeAccount(2);
  final amount = BigInt.from(1000);
  final networkFee = BigInt.from(10);
  late WalletTestBed bed;
  late FakeTransactionSubmissionService submission;

  setUp(() async {
    // A submitted send records its recipient among the recent addresses.
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
    bed = WalletTestBed();
    submission = FakeTransactionSubmissionService();
  });

  List<Override> overrides() => [
    ...bed.overrides,
    balancesServiceProvider.overrideWithValue(FakeBalancesService()),
    transactionSubmissionServiceProvider.overrideWithValue(submission),
  ];

  Future<SendOutcome> submit(WidgetRef ref) => RegularSendStrategy(account: sender).submit(
    ref,
    recipientAddress: recipient.accountId,
    amount: amount,
    fee: RegularFee(networkFee: networkFee, amount: amount),
    isPayMode: false,
  );

  group('submit', () {
    testWidgets('asks for approval with the send\'s reason, then submits and links to the transaction', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());

      final outcome = await submit(ref);

      expect(bed.userApproval.reasons, [ref.read(l10nProvider).sendReviewAuthReason]);
      expect(submission.transfers, [(recipient.accountId, amount, networkFee)]);
      expect((outcome as SendSubmitted).terminal.explorerUrl, '${AppConstants.explorerEndpoint}/transactions/0xtxhash');
    });

    testWidgets('a declined approval submits nothing and says authentication is required', (tester) async {
      bed.userApproval.answer = () async => ApprovalResult.declined;
      final ref = await pumpRef(tester, overrides: overrides());

      final outcome = await submit(ref);

      expect((outcome as SendFailed).message, ref.read(l10nProvider).sendReviewAuthRequired);
      expect(submission.transfers, isEmpty);
    });

    testWidgets('an approval that is not set up submits nothing and says authentication is required', (tester) async {
      bed.userApproval.answer = () async => ApprovalResult.notSetUp;
      final ref = await pumpRef(tester, overrides: overrides());

      final outcome = await submit(ref);

      expect((outcome as SendFailed).message, ref.read(l10nProvider).sendReviewAuthRequired);
      expect(submission.transfers, isEmpty);
    });
  });

  group('reviewRows', () {
    Future<List<SendReviewRow>> rows(WidgetTester tester, {bool feeIsEstimate = false, bool sendAll = false}) async {
      final read = await pumpWatched(
        tester,
        overrides: overrides(),
        build: (ref) => RegularSendStrategy(account: sender).reviewRows(
          ref,
          recipientAddress: ' ${recipient.accountId} ',
          amount: BigInt.from(5) * NumberFormattingService.scaleFactorBigInt,
          fee: RegularFee(networkFee: NumberFormattingService.scaleFactorBigInt),
          feeIsEstimate: feeIsEstimate,
          sendAll: sendAll,
        ),
      );
      return read();
    }

    final l10n = lookupAppLocalizations(const Locale('en'));
    const symbol = AppConstants.tokenSymbol;

    testWidgets('are the recipient, the amount, the network fee and their sum, each named as such', (tester) async {
      expect(await rows(tester), [
        SendReviewText(l10n.sendReviewTo, recipient.accountId, kind: SendReviewRowKind.recipient),
        SendReviewText(l10n.sendReviewAmount, '5 $symbol', kind: SendReviewRowKind.amount),
        SendReviewText(l10n.sendReviewNetworkFee, '1 $symbol', kind: SendReviewRowKind.fee),
        SendReviewText(l10n.sendReviewYouPay, '6 $symbol', kind: SendReviewRowKind.total),
      ]);
    });

    testWidgets('mark the fee and the sum as estimates until the fee is exact', (tester) async {
      expect(await rows(tester, feeIsEstimate: true), [
        SendReviewText(l10n.sendReviewTo, recipient.accountId, kind: SendReviewRowKind.recipient),
        SendReviewText(l10n.sendReviewAmount, '5 $symbol', kind: SendReviewRowKind.amount),
        SendReviewText(l10n.sendReviewNetworkFee, '~1 $symbol', kind: SendReviewRowKind.fee),
        SendReviewText(l10n.sendReviewYouPay, '~6 $symbol', kind: SendReviewRowKind.total),
      ]);
    });

    testWidgets('of a max send mark the fee and the amount instead: the sum is the whole balance', (tester) async {
      expect(await rows(tester, feeIsEstimate: true, sendAll: true), [
        SendReviewText(l10n.sendReviewTo, recipient.accountId, kind: SendReviewRowKind.recipient),
        SendReviewText(l10n.sendReviewAmount, '~5 $symbol', kind: SendReviewRowKind.amount),
        SendReviewText(l10n.sendReviewNetworkFee, '~1 $symbol', kind: SendReviewRowKind.fee),
        SendReviewText(l10n.sendReviewYouPay, '6 $symbol', kind: SendReviewRowKind.total),
      ]);
    });
  });
}
