import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/proposal_list_tile.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_activity_section.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/proposal_row.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/models/fiat_currency.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';

import '../extensions.dart';
import '../fakes.dart';

/// The proposals the indexer holds for the multisig.
class _FakeMultisigService extends Fake implements MultisigService {
  _FakeMultisigService({this.open = const [], this.past = const []});

  final List<MultisigProposal> open;
  final List<MultisigProposal> past;

  @override
  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) async => open;

  @override
  Future<List<MultisigProposal>> getPastProposals(MultisigAccount msig) async => past;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help';
  final me = makeAccount(1);
  final alsoMe = makeAccount(2);
  final them = makeAccount(3).accountId;
  final recipient = makeAccount(4).accountId;
  final msig = MultisigAccount(
    name: 'Team',
    accountId: 'qzteam${'x' * 40}',
    signers: [me.accountId, alsoMe.accountId, them],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: me.accountId,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
  });

  MultisigProposal proposal({
    int id = 1,
    BigInt? amount,
    DateTime? updatedAt,
    List<String> approvals = const [],
    MultisigProposalStatus status = MultisigProposalStatus.active,
  }) => MultisigProposal(
    entityId: 'proposal-$id',
    id: id,
    multisigAddress: msig.accountId,
    proposer: me.accountId,
    createdAt: DateTime.utc(2026),
    updatedAt: updatedAt ?? DateTime.utc(2026),
    pallet: '',
    call: '',
    recipient: recipient,
    amount: amount ?? BigInt.from(500),
    expiryBlock: 1000,
    approvals: approvals,
    deposit: BigInt.zero,
    status: status,
    threshold: msig.threshold,
    signerCount: msig.signers.length,
  );

  List<Override> overrides({List<MultisigProposal> open = const [], List<MultisigProposal> past = const []}) => [
    multisigServiceProvider.overrideWithValue(_FakeMultisigService(open: open, past: past)),
    accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: [me, alsoMe])),
    txAmountDisplayProvider.overrideWithValue((
      BigInt amount, {
      required bool isSend,
      int tokenDecimals = 12,
      bool withTokenSymbol = true,
      bool withSignPrefix = true,
    }) {
      return CurrencyDisplayState(
        primaryAmount: '${isSend ? '-' : '+'}$amount',
        secondaryAmount: '',
        selectedFiat: FiatCurrency.usd,
      );
    }),
  ];

  ProviderContainer containerOf(WidgetTester tester, Type widget) =>
      ProviderScope.containerOf(tester.element(find.byType(widget)));

  group('what an open proposal row says it waits for', () {
    /// Shows [shown]'s row, as the devices [localSignerIds] see it, with
    /// what [inFlight] puts on its way to the chain.
    Future<void> pumpRow(
      WidgetTester tester,
      MultisigProposal shown, {
      List<String>? localSignerIds,
      void Function(ProviderContainer container)? inFlight,
    }) async {
      await tester.pumpApp(
        Material(
          child: ProposalRow(proposal: shown, localSignerIds: localSignerIds ?? [me.accountId]),
        ),
        overrides: overrides(),
      );
      inFlight?.call(containerOf(tester, ProposalRow));
      await tester.pump();
    }

    void approving(ProviderContainer container, String approverId) => container
        .read(pendingMultisigApprovalsProvider.notifier)
        .add(
          PendingMultisigApprovalEvent.create(
            multisigAddress: msig.accountId,
            proposalId: 1,
            approverId: approverId,
            recipient: recipient,
            amount: BigInt.from(500),
          ),
        );

    void executing(ProviderContainer container) => container
        .read(pendingMultisigExecutionsProvider.notifier)
        .add(
          PendingMultisigExecutionEvent.create(
            multisigAddress: msig.accountId,
            proposalId: 1,
            executorId: me.accountId,
            recipient: recipient,
            amount: BigInt.from(500),
            fee: BigInt.one,
          ),
        );

    void cancelling(ProviderContainer container) => container
        .read(pendingMultisigCancellationsProvider.notifier)
        .add(
          PendingMultisigCancellationEvent.create(
            multisigAddress: msig.accountId,
            proposalId: 1,
            proposerId: me.accountId,
            recipient: recipient,
            amount: BigInt.from(500),
            fee: BigInt.one,
          ),
        );

    /// Every word and badge a row can show; a case expects exactly its own.
    final marks = [
      l10n.multisigStatusProposed,
      l10n.multisigStatusApproved,
      l10n.multisigStatusExecuted,
      l10n.activityTxApproving,
      l10n.activityTxExecuting,
      l10n.activityTxCancelling,
    ];

    void expectShows(List<String> shown) {
      for (final mark in marks) {
        expect(find.text(mark), shown.contains(mark) ? findsOneWidget : findsNothing, reason: mark);
      }
      for (final text in shown.where((text) => !marks.contains(text))) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    }

    testWidgets('open, not yet signed by this device', (tester) async {
      await pumpRow(tester, proposal());
      expectShows(['0/2', l10n.multisigStatusProposed]);
    });

    testWidgets('open, signed by this device', (tester) async {
      await pumpRow(tester, proposal(approvals: [me.accountId]));
      expectShows(['1/2', l10n.multisigStatusApproved]);
    });

    testWidgets("this device's approval on its way", (tester) async {
      await pumpRow(tester, proposal(), inFlight: (container) => approving(container, me.accountId));
      expectShows([l10n.activityTxApproving]);
    });

    testWidgets('two signers here, one signed and the other approving', (tester) async {
      await pumpRow(
        tester,
        proposal(approvals: [me.accountId]),
        localSignerIds: [me.accountId, alsoMe.accountId],
        inFlight: (container) => approving(container, alsoMe.accountId),
      );
      expectShows([l10n.activityTxApproving]);
    });

    testWidgets('two signers here, one signed and the other not yet', (tester) async {
      await pumpRow(tester, proposal(approvals: [me.accountId]), localSignerIds: [me.accountId, alsoMe.accountId]);
      expectShows(['1/2', l10n.multisigStatusProposed]);
    });

    testWidgets('two signers here, only one approving: the other has yet to sign', (tester) async {
      await pumpRow(
        tester,
        proposal(),
        localSignerIds: [me.accountId, alsoMe.accountId],
        inFlight: (container) => approving(container, me.accountId),
      );
      expectShows(['0/2', l10n.multisigStatusProposed]);
    });

    testWidgets('an execution on its way', (tester) async {
      await pumpRow(tester, proposal(approvals: [me.accountId, them]), inFlight: executing);
      expectShows([l10n.activityTxExecuting]);
    });

    testWidgets('a cancellation on its way', (tester) async {
      await pumpRow(tester, proposal(), inFlight: cancelling);
      expectShows([l10n.activityTxCancelling]);
    });

    testWidgets('an execution and an approval on their way: the execution is named', (tester) async {
      await pumpRow(
        tester,
        proposal(),
        inFlight: (container) {
          approving(container, me.accountId);
          executing(container);
        },
      );
      expectShows([l10n.activityTxExecuting]);
    });

    testWidgets('a closed proposal shows how it ended', (tester) async {
      await pumpRow(tester, proposal(approvals: [me.accountId, them], status: MultisigProposalStatus.executed));
      expectShows([l10n.multisigStatusExecuted]);
    });
  });

  group("a multisig's home section", () {
    Future<void> pumpSection(
      WidgetTester tester, {
      List<MultisigProposal> open = const [],
      List<MultisigProposal> past = const [],
      List<TransactionEvent> transfers = const [],
      List<PendingMultisigProposalEvent> proposing = const [],
    }) async {
      await tester.pumpApp(
        Material(
          child: SingleChildScrollView(
            child: MultisigActivitySection(
              msig: msig,
              txAsync: AsyncValue.data(CombinedTransactionsList.empty.copyWith(otherTransfers: transfers)),
            ),
          ),
        ),
        overrides: overrides(open: open, past: past),
      );
      final pending = containerOf(tester, MultisigActivitySection).read(pendingMultisigProposalsProvider.notifier);
      for (final event in proposing) {
        pending.add(event);
      }
      // The indexer's answers, then what they draw.
      await tester.pump();
      await tester.pump();
    }

    testWidgets('open proposals list the ones being proposed first, then the latest changed', (tester) async {
      await pumpSection(
        tester,
        open: [
          proposal(id: 1, amount: BigInt.from(100), updatedAt: DateTime.utc(2026, 1)),
          proposal(id: 2, amount: BigInt.from(200), updatedAt: DateTime.utc(2026, 2)),
        ],
        proposing: [
          PendingMultisigProposalEvent.create(
            msig: msig,
            proposerId: me.accountId,
            recipient: recipient,
            amount: BigInt.from(300),
            expiryBlock: 1000,
            fee: BigInt.one,
            deposit: BigInt.one,
            palletFee: BigInt.one,
          ),
        ],
      );

      final amounts = tester.widgetList<ProposalListTile>(find.byType(ProposalListTile)).map((tile) => tile.amount);
      expect(amounts, [BigInt.from(300), BigInt.from(200), BigInt.from(100)]);
      expect(find.text(l10n.multisigNoOpenProposals), findsNothing);
    });

    testWidgets('with no open proposals, it says so', (tester) async {
      await pumpSection(tester);

      expect(find.byType(ProposalListTile), findsNothing);
      expect(find.text(l10n.multisigNoOpenProposals), findsOneWidget);
    });

    testWidgets("the activity is past proposals and transfers, newest first, without the multisig's own sends", (
      tester,
    ) async {
      TransferEvent transfer({required String from, required String to, required int amount, required int day}) =>
          TransferEvent(
            id: 'transfer-$amount',
            from: from,
            to: to,
            amount: BigInt.from(amount),
            timestamp: DateTime.utc(2026, 3, day),
            fee: BigInt.one,
            blockNumber: day,
            blockHash: '0xblock$day',
          );
      await pumpSection(
        tester,
        past: [
          proposal(
            id: 7,
            amount: BigInt.from(500),
            updatedAt: DateTime.utc(2026, 3, 2),
            status: MultisigProposalStatus.executed,
          ),
        ],
        transfers: [
          transfer(from: me.accountId, to: msig.accountId, amount: 300, day: 3),
          // What the executed proposal sent: the proposal stands for it.
          transfer(from: msig.accountId, to: recipient, amount: 700, day: 4),
        ],
      );

      expect(find.text('-700'), findsNothing);
      final received = tester.getTopLeft(find.text('+300')).dy;
      final executed = tester.getTopLeft(find.text('-500')).dy;
      expect(received, lessThan(executed));
    });
  });
}
