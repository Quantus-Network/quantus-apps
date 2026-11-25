import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/logout_service.dart';
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

  group('a cold wallet\'s signing', () {
    Future<KeystoneSigningSession> session(WidgetRef ref, {required bool sendAll}) async {
      final outcome = await RegularSendStrategy(account: makeAccount(3, accountType: AccountType.keystone)).submit(
        ref,
        recipientAddress: recipient.accountId,
        amount: amount,
        fee: RegularFee(networkFee: networkFee, amount: sendAll ? null : amount, sendAll: sendAll),
        isPayMode: false,
        sendAll: sendAll,
      );
      return (outcome as SendNeedsHardwareSignature).session;
    }

    testWidgets('of a maximum send says what the cold wallet shows of it: the entire transferable balance', (
      tester,
    ) async {
      final ref = await pumpRef(tester, overrides: overrides());

      final signing = await session(ref, sendAll: true);

      expect((signing.primaryDetail, signing.secondaryDetail), ('Entire transferable balance', recipient.accountId));
    });

    testWidgets('of a send of an amount says that amount', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());

      final signing = await session(ref, sendAll: false);

      expect(signing.primaryDetail, endsWith(' QTC'));
    });
  });

  group('a wallet reset', () {
    Future<KeystoneSigningSession> hardwareSession(WidgetRef ref) async {
      final outcome = await RegularSendStrategy(account: makeAccount(3, accountType: AccountType.keystone)).submit(
        ref,
        recipientAddress: recipient.accountId,
        amount: amount,
        fee: RegularFee(networkFee: networkFee, amount: amount),
        isPayMode: false,
      );
      return (outcome as SendNeedsHardwareSignature).session;
    }

    Future<String> submitHardware(KeystoneSigningSession session, WidgetRef ref) =>
        session.submitSigned(ref, unsignedData: makeUnsignedTransactionData(), signatureWithPublicKey: Uint8List(0));

    testWidgets('during the approval prompt submits nothing and says the send failed', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      bed.userApproval.answer = () async {
        await ref.read(logoutServiceProvider).logout();
        return ApprovalResult.approved;
      };

      final outcome = await submit(ref);

      expect((outcome as SendFailed).message, ref.read(l10nProvider).sendReviewSubmitFailed);
      expect(submission.transfers, isEmpty);
    });

    testWidgets('while a send goes out keeps its recipient out of the recent addresses', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final held = submission.holdTransfer = Completer<void>();
      final sent = submit(ref);
      await tester.pump();

      await ref.read(logoutServiceProvider).logout();
      held.complete();
      final outcome = await sent;
      await tester.pump();

      expect(outcome, isA<SendSubmitted>());
      expect(await RecentAddressesService().getAddresses(), isEmpty);
    });

    testWidgets('whose wipe is still running when a send answers keeps its recipient out', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final held = submission.holdTransfer = Completer<void>();
      final sent = submit(ref);
      await tester.pump();
      final wipe = bed.substrate.holdWipe = Completer<void>();

      final logout = ref.read(logoutServiceProvider).logout();
      await tester.pump();
      held.complete();
      expect(await sent, isA<SendSubmitted>());
      await tester.pump();
      final savedDuringTheWipe = await RecentAddressesService().getAddresses();
      wipe.complete();
      await logout;

      expect(savedDuringTheWipe, isEmpty);
      expect(bed.droppedByReset.single, contains('recipient'));
      expect(await RecentAddressesService().getAddresses(), isEmpty);
    });

    testWidgets('while a hardware send goes out keeps its recipient out of the recent addresses', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final session = await hardwareSession(ref);
      final held = submission.holdTransfer = Completer<void>();
      final sent = submitHardware(session, ref);
      await tester.pump();

      await ref.read(logoutServiceProvider).logout();
      held.complete();
      expect(await sent, '0xtxhash');
      await tester.pump();

      expect(await RecentAddressesService().getAddresses(), isEmpty);
    });

    testWidgets('before a Keystone signature comes back sends nothing and saves no recipient', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final session = await hardwareSession(ref);

      await ref.read(logoutServiceProvider).logout();

      await expectLater(submitHardware(session, ref), throwsStateError);
      await tester.pump();
      expect(submission.transfers, isEmpty);
      expect(await RecentAddressesService().getAddresses(), isEmpty);
    });

    testWidgets('still wiping when a Keystone signature comes back sends nothing', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final session = await hardwareSession(ref);
      final wipe = bed.substrate.holdWipe = Completer<void>();
      final logout = ref.read(logoutServiceProvider).logout();
      await tester.pump();

      await expectLater(submitHardware(session, ref), throwsStateError);
      await tester.pump();
      expect(submission.transfers, isEmpty);

      wipe.complete();
      await logout;
    });

    testWidgets('that failed leaves a Keystone signature able to send', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final session = await hardwareSession(ref);
      bed.substrate.logoutError = StateError('the wipe failed');
      await expectLater(ref.read(logoutServiceProvider).logout(), throwsStateError);

      expect(await submitHardware(session, ref), '0xtxhash');
      await tester.pump();

      expect(submission.transfers, hasLength(1));
      expect(await RecentAddressesService().getAddresses(), [recipient.accountId]);
    });

    testWidgets('before a Keystone send starts leaves that send able to go out', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      await ref.read(logoutServiceProvider).logout();

      expect(await submitHardware(await hardwareSession(ref), ref), '0xtxhash');
      await tester.pump();

      expect(submission.transfers, hasLength(1));
      expect(await RecentAddressesService().getAddresses(), [recipient.accountId]);
    });

    testWidgets('that did not happen leaves a send\'s recipient among the recent addresses', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());

      await submit(ref);
      await tester.pump();

      expect(await RecentAddressesService().getAddresses(), [recipient.accountId]);
    });

    testWidgets('that did not happen leaves a hardware send\'s recipient there too', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());

      await submitHardware(await hardwareSession(ref), ref);
      await tester.pump();

      expect(await RecentAddressesService().getAddresses(), [recipient.accountId]);
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
