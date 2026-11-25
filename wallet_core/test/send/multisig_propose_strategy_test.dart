import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/send/multisig_propose_strategy.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/utils/explorer_url.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

import '../fakes.dart';

/// The chain at block 100, where any block is reached at the start of 2026.
class _FakeMultisigService extends Fake implements MultisigService {
  /// The account each proposal's cost was estimated for.
  final quotedSigners = <String>[];

  @override
  Future<int> currentBlockNumber() async => 100;

  @override
  DateTime blockToTime(int targetBlock, int currentBlock) => DateTime.utc(2026);

  @override
  Future<ProposeFeeBreakdown> estimateProposeFeeBreakdown({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
  }) async {
    quotedSigners.add(signer.accountId);
    return ProposeFeeBreakdown(networkFee: BigInt.one, deposit: BigInt.one, creationFee: BigInt.one, expiryBlock: 1000);
  }
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

    testWidgets('a submitted proposal has the explorer\'s page of the transaction that created it', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());

      final outcome = await submit(ref);

      expect(
        (outcome as SendSubmitted).terminal.explorerUrl,
        '${AppConstants.explorerEndpoint}/multisig-proposal-created/0xproposal',
      );
    });

    testWidgets('a submitted proposal is confirmed only once the wallet has seen its transaction create it', (
      tester,
    ) async {
      final ref = await pumpRef(tester, overrides: overrides());

      final confirmation = ((await submit(ref)) as SendSubmitted).confirmation!;

      expect(ref.read(confirmation), SendConfirmation.pending);

      ref.read(multisigProposalConfirmationsProvider.notifier).settle('0xother', SendConfirmation.confirmed);
      expect(ref.read(confirmation), SendConfirmation.pending);

      ref.read(multisigProposalConfirmationsProvider.notifier).settle('0xproposal', SendConfirmation.confirmed);
      expect(ref.read(confirmation), SendConfirmation.confirmed);
    });

    group('what the member holds', () {
      // What proposing costs the member: the fee's three parts.
      final cost = BigInt.from(4) * oneToken;
      late BigInt memberHolds;

      List<Override> withBalance() => [
        ...overrides(),
        balanceProviderFamily.overrideWith((ref, accountId) => memberHolds),
      ];

      testWidgets('exactly the cost is enough to propose', (tester) async {
        memberHolds = cost;
        final ref = await pumpRef(tester, overrides: withBalance());

        expect(await submit(ref), isA<SendSubmitted>());
        expect(submission.proposals, hasLength(1));
      });

      testWidgets('less than the cost proposes nothing, says the member cannot pay, and asks for no approval', (
        tester,
      ) async {
        memberHolds = cost - BigInt.one;
        final ref = await pumpRef(tester, overrides: withBalance());

        final outcome = await submit(ref);

        expect((outcome as SendFailed).message, ref.read(l10nProvider).multisigProposeFeePayerInsufficient);
        expect(bed.userApproval.reasons, isEmpty);
        expect(submission.proposals, isEmpty);
      });

      testWidgets('falling below the cost while approval is asked proposes nothing, and says the member cannot pay', (
        tester,
      ) async {
        memberHolds = cost;
        final ref = await pumpRef(tester, overrides: withBalance());
        bed.userApproval.answer = () async {
          memberHolds = cost - BigInt.one;
          ref.invalidate(balanceProviderFamily(member.accountId));
          return ApprovalResult.approved;
        };

        final outcome = await submit(ref);

        expect((outcome as SendFailed).message, ref.read(l10nProvider).multisigProposeFeePayerInsufficient);
        expect(bed.userApproval.reasons, hasLength(1));
        expect(submission.proposals, isEmpty);
      });
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

  group('the account that proposes', () {
    final cost = BigInt.from(4) * oneToken;
    late _FakeMultisigService chain;
    late Map<String, BigInt> holds;

    setUp(() {
      chain = _FakeMultisigService();
      holds = {member.accountId: cost, other.accountId: cost};
    });

    List<Override> bothHere({Account? second}) => [
      ...bed.overrides,
      accountsProvider.overrideWith(
        (ref) => AccountsNotifier(bed.accounts, initialAccounts: [member, second ?? other]),
      ),
      multisigServiceProvider.overrideWithValue(chain),
      transactionSubmissionServiceProvider.overrideWithValue(submission),
      balanceProviderFamily.overrideWith((ref, accountId) => holds[accountId] ?? BigInt.zero),
    ];

    Future<SendOutcome> submitAs(WidgetRef ref, MultisigProposeStrategy strategy) => strategy.submit(
      ref,
      recipientAddress: recipient.accountId,
      amount: BigInt.from(5) * oneToken,
      fee: fee,
      isPayMode: false,
    );

    testWidgets('with no proposer given, the member is priced, pays and signs', (tester) async {
      final strategy = MultisigProposeStrategy(msig: msig);
      late WidgetRef ref;
      await pumpWatched(
        tester,
        overrides: bothHere(),
        build: (watching) {
          ref = watching;
          return watching.watch(strategy.feeProvider(recipient: recipient.accountId, amount: oneToken));
        },
      );
      await tester.pump();
      await submitAs(ref, strategy);

      expect(strategy.proposerId, member.accountId);
      expect(chain.quotedSigners, [member.accountId]);
      expect(strategy.feePayerBalanceProvider, effectiveBalanceProviderFamily(member.accountId));
      expect(submission.proposalSigners, [member.accountId]);
    });

    testWidgets('another signer given as the proposer is priced, pays, is named on the review and signs, not the '
        'member', (tester) async {
      final strategy = MultisigProposeStrategy(msig: msig, proposerId: other.accountId);
      late WidgetRef ref;
      final read = await pumpWatched(
        tester,
        overrides: bothHere(),
        build: (watching) {
          ref = watching;
          return (
            fee: watching.watch(strategy.feeProvider(recipient: recipient.accountId, amount: oneToken)),
            rows: strategy.reviewRows(
              watching,
              recipientAddress: recipient.accountId,
              amount: BigInt.from(5) * oneToken,
              fee: fee,
            ),
          );
        },
      );
      await tester.pump();

      expect(read().fee.fee, isNotNull);
      expect(chain.quotedSigners, [other.accountId]);
      expect(strategy.feePayerBalanceProvider, effectiveBalanceProviderFamily(other.accountId));
      expect((read().rows.first as SendReviewAddress).address, other.accountId);
      expect(await submitAs(ref, strategy), isA<SendSubmitted>());
      expect(submission.proposalSigners, [other.accountId]);
    });

    testWidgets('what the proposer holds decides whether it can pay, not what the member holds', (tester) async {
      holds = {member.accountId: cost, other.accountId: cost - BigInt.one};
      final strategy = MultisigProposeStrategy(msig: msig, proposerId: other.accountId);
      late WidgetRef ref;
      final read = await pumpWatched(
        tester,
        overrides: bothHere(),
        build: (watching) {
          ref = watching;
          return strategy.affordabilityError(watching, fee, watching.watch(l10nProvider));
        },
      );
      await tester.pump();
      final l10n = ref.read(l10nProvider);

      expect(read(), l10n.multisigProposeFeePayerInsufficient);
      expect(((await submitAs(ref, strategy)) as SendFailed).message, l10n.multisigProposeFeePayerInsufficient);
      expect(submission.proposals, isEmpty);
    });

    testWidgets('a cold wallet signer given as the proposer signs on its cold wallet', (tester) async {
      final coldOther = makeAccount(2, accountType: AccountType.keystone);
      final ref = await pumpRef(tester, overrides: bothHere(second: coldOther));

      final outcome = await submitAs(ref, MultisigProposeStrategy(msig: msig, proposerId: coldOther.accountId));

      expect((outcome as SendNeedsHardwareSignature).session.account.accountId, coldOther.accountId);
      expect(bed.userApproval.reasons, isEmpty);
    });
  });

  testWidgets('a Keystone member signs the proposal with its amount, shown as an amount', (tester) async {
    final keystoneMember = makeAccount(1, accountType: AccountType.keystone);
    final ref = await pumpRef(
      tester,
      overrides: [
        ...bed.overrides,
        accountsProvider.overrideWith((ref) => AccountsNotifier(bed.accounts, initialAccounts: [keystoneMember])),
        multisigServiceProvider.overrideWithValue(_FakeMultisigService()),
        transactionSubmissionServiceProvider.overrideWithValue(submission),
      ],
    );

    final session = ((await submit(ref)) as SendNeedsHardwareSignature).session;

    expect(session.primaryDetail, endsWith(' QTC'));
    expect(session.primaryIsAmount, isTrue);
  });

  group('a wallet reset', () {
    final keystoneMember = makeAccount(1, accountType: AccountType.keystone);

    List<Override> keystoneOverrides() => [
      ...bed.overrides,
      accountsProvider.overrideWith((ref) => AccountsNotifier(bed.accounts, initialAccounts: [keystoneMember])),
      multisigServiceProvider.overrideWithValue(_FakeMultisigService()),
      transactionSubmissionServiceProvider.overrideWithValue(submission),
    ];

    Future<KeystoneSigningSession> hardwareSession(WidgetRef ref) async =>
        ((await submit(ref)) as SendNeedsHardwareSignature).session;

    Future<String> submitHardware(KeystoneSigningSession session, WidgetRef ref) =>
        session.submitSigned(ref, unsignedData: makeUnsignedTransactionData(), signatureWithPublicKey: Uint8List(0));

    testWidgets('a Keystone member\'s hand-off links its receipt to the created proposal and waits for it', (
      tester,
    ) async {
      final ref = await pumpRef(tester, overrides: keystoneOverrides());

      final hardware = (await submit(ref)) as SendNeedsHardwareSignature;

      expect(hardware.terminalForHash('0xabc').explorerUrl, multisigProposalExplorerUrl('0xabc'));
      expect(hardware.confirmationForHash!('0xabc'), multisigProposalConfirmationProvider('0xabc'));
    });

    testWidgets('during the approval prompt proposes nothing and says the proposal failed', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      bed.userApproval.answer = () async {
        await ref.read(logoutServiceProvider).logout();
        return ApprovalResult.approved;
      };

      final outcome = await submit(ref);

      expect((outcome as SendFailed).message, ref.read(l10nProvider).multisigProposeSubmitFailed);
      expect(submission.proposals, isEmpty);
      expect(bed.droppedByReset.single, contains('proposal'));
    });

    testWidgets('before a Keystone signature comes back proposes nothing', (tester) async {
      final ref = await pumpRef(tester, overrides: keystoneOverrides());
      final session = await hardwareSession(ref);

      await ref.read(logoutServiceProvider).logout();

      await expectLater(submitHardware(session, ref), throwsStateError);
      expect(submission.proposals, isEmpty);
    });

    testWidgets('while a proposal goes out keeps its recipient out of the recent addresses', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final held = submission.holdTransfer = Completer<void>();
      final sent = submit(ref);
      await tester.pump();

      await ref.read(logoutServiceProvider).logout();
      held.complete();
      expect(await sent, isA<SendSubmitted>());
      await tester.pump();

      expect(await RecentAddressesService().getAddresses(), isEmpty);
      expect(bed.droppedByReset.single, contains('proposal'));
    });

    testWidgets('that also closed the screen still reports a proposal that went out', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());
      final held = submission.holdTransfer = Completer<void>();
      final sent = submit(ref);
      await tester.pump();

      await ref.read(logoutServiceProvider).logout();
      await tester.pumpWidget(const SizedBox());
      held.complete();

      expect(await sent, isA<SendSubmitted>());
    });

    testWidgets('while a Keystone proposal goes out keeps its recipient out too', (tester) async {
      final ref = await pumpRef(tester, overrides: keystoneOverrides());
      final session = await hardwareSession(ref);
      final held = submission.holdTransfer = Completer<void>();
      final sent = submitHardware(session, ref);
      await tester.pump();

      await ref.read(logoutServiceProvider).logout();
      held.complete();
      expect(await sent, '0xproposal');
      await tester.pump();

      expect(await RecentAddressesService().getAddresses(), isEmpty);
    });

    testWidgets('that did not happen leaves a proposal\'s recipient among the recent addresses', (tester) async {
      final ref = await pumpRef(tester, overrides: overrides());

      await submit(ref);
      await tester.pump();

      expect(await RecentAddressesService().getAddresses(), [recipient.accountId]);
      expect(bed.droppedByReset, isEmpty);
    });

    testWidgets('that did not happen leaves a Keystone proposal\'s recipient there too', (tester) async {
      final ref = await pumpRef(tester, overrides: keystoneOverrides());

      await submitHardware(await hardwareSession(ref), ref);
      await tester.pump();

      expect(submission.proposals, hasLength(1));
      expect(await RecentAddressesService().getAddresses(), [recipient.accountId]);
    });
  });

  test('a threshold is written as the phone shows it, and two are equal when their parts are', () {
    const threshold = SendReviewThreshold('THRESHOLD', threshold: 2, signers: 3);

    expect(threshold.text, '2/3');
    expect(threshold, const SendReviewThreshold('THRESHOLD', threshold: 2, signers: 3));
    expect(threshold, isNot(const SendReviewThreshold('THRESHOLD', threshold: 3, signers: 3)));
    expect(threshold, isNot(const SendReviewThreshold('THRESHOLD', threshold: 2, signers: 4)));
    expect(threshold.kind, SendReviewRowKind.detail);
  });

  testWidgets('reviewRows say what each line is, name the proposer by address, give the threshold in numbers, and '
      'give the expiry a time once the block is known', (tester) async {
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
      SendReviewAddress(l10n.multisigProposeProposerLabel, member.accountId, kind: SendReviewRowKind.signer),
      SendReviewText(l10n.sendReviewAmount, '5 $symbol', kind: SendReviewRowKind.amount),
      SendReviewThreshold(l10n.multisigProposeThresholdLabel, threshold: 2, signers: 2),
      SendReviewExpiry(l10n.multisigProposeExpiresLabel, expiry),
      SendReviewText(l10n.sendReviewNetworkFee, '1 $symbol', kind: SendReviewRowKind.fee),
      SendReviewText(l10n.multisigProposalDepositLabel, '2 $symbol', kind: SendReviewRowKind.deposit),
      SendReviewText(l10n.multisigProposeFeeRowLabel, '1 $symbol', kind: SendReviewRowKind.charge),
      SendReviewText(l10n.multisigProposeMemberTotalLabel, '4 $symbol', kind: SendReviewRowKind.total),
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
