import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _now = DateTime.now();
const _bob = 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu';

MultisigProposal _proposal({
  required int id,
  required int tokens,
  required Duration changed,
  List<String> approvals = const [],
  MultisigProposalStatus status = MultisigProposalStatus.active,
}) => MultisigProposal(
  entityId: 'proposal-$id',
  id: id,
  multisigAddress: teamMultisig.accountId,
  proposer: 'qzOther',
  createdAt: _now.subtract(changed),
  updatedAt: _now.subtract(changed),
  pallet: '',
  call: '',
  recipient: _bob,
  amount: oneToken * BigInt.from(tokens),
  expiryBlock: 1300000,
  approvals: approvals,
  deposit: oneToken,
  status: status,
  threshold: teamMultisig.threshold,
  signerCount: teamMultisig.signers.length,
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Future<void> _openTeam(WidgetTester tester, FakeSendChain chain) => pumpShell(
  tester,
  overrides: shellOverrides(
    accounts: const [mainAccount],
    settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(teamMultisig), multisigs: [teamMultisig]),
    balances: oneTokenEach,
    chain: chain,
  ),
);

/// The open proposals' rows, by what they move, top to bottom.
List<BigInt> _openAmounts(WidgetTester tester) => [
  for (final row in tester.widgetList<OpenProposalRowView>(find.byType(OpenProposalRowView))) row.amount,
];

void main() {
  testOnMac('a multisig\'s open proposals are a panel above Activity: being proposed first, then the latest changed', (
    tester,
  ) async {
    final chain = FakeSendChain()
      ..openProposals = [
        _proposal(id: 1, tokens: 100, changed: const Duration(days: 2)),
        _proposal(id: 2, tokens: 200, changed: const Duration(hours: 3)),
      ];
    await _openTeam(tester, chain);
    _container(tester)
        .read(pendingMultisigProposalsProvider.notifier)
        .add(
          PendingMultisigProposalEvent.create(
            msig: teamMultisig,
            proposerId: 'qzMain',
            recipient: _bob,
            amount: oneToken * BigInt.from(300),
            expiryBlock: 1300000,
            fee: BigInt.one,
            deposit: oneToken,
            palletFee: BigInt.one,
          ),
        );
    await tester.pumpAndSettle();

    expect(_openAmounts(tester), [
      for (final tokens in [300, 200, 100]) oneToken * BigInt.from(tokens),
    ]);
    expect(find.text(_l10n.multisigOpenProposals), findsOne);
    expect(
      tester.getRect(find.byType(OpenProposalsPanel)).bottom,
      lessThan(tester.getRect(find.byType(ActivityPanel)).top),
    );
  });

  testOnMac('with none open it says so', (tester) async {
    await _openTeam(tester, FakeSendChain());

    expect(
      find.descendant(of: find.byType(OpenProposalsPanel), matching: find.text(_l10n.multisigNoOpenProposals)),
      findsOne,
    );
  });

  testOnMac('each row says what it waits for, how far its approvals are, and whom it pays', (tester) async {
    final chain = FakeSendChain()
      ..openProposals = [
        _proposal(id: 1, tokens: 100, changed: const Duration(hours: 1), approvals: const ['qzOther']),
        _proposal(id: 2, tokens: 200, changed: const Duration(hours: 2), approvals: const ['qzMain']),
      ];
    await _openTeam(tester, chain);

    // Main, this device's signer, has yet to sign the first, and signed the second.
    expect(find.text(_l10n.multisigStatusProposed), findsOne);
    expect(find.text(_l10n.multisigStatusApproved), findsOne);
    expect(
      find.descendant(of: find.byType(OpenProposalsPanel), matching: find.byType(ApprovalMarks)),
      findsNWidgets(2),
    );
    expect(find.text(_l10n.desktopProposeCountOf(1, 2)), findsNWidgets(2));
    expect(find.descendant(of: find.byType(OpenProposalsPanel), matching: find.text(_bob)), findsNWidgets(2));

    _container(tester)
        .read(pendingMultisigExecutionsProvider.notifier)
        .add(
          PendingMultisigExecutionEvent.create(
            multisigAddress: teamMultisig.accountId,
            proposalId: 2,
            executorId: 'qzMain',
            recipient: _bob,
            amount: oneToken * BigInt.from(200),
            fee: BigInt.one,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text(_l10n.activityTxExecuting), findsOne);
    expect(find.text(_l10n.multisigStatusApproved), findsNothing);
  });

  testOnMac('its Activity is its past proposals, named by how they ended, and what it received', (tester) async {
    final chain = FakeSendChain()
      ..pastProposals = [
        _proposal(id: 7, tokens: 75, changed: const Duration(hours: 3), status: MultisigProposalStatus.executed),
        _proposal(id: 8, tokens: 30, changed: const Duration(days: 1), status: MultisigProposalStatus.cancelled),
      ]
      ..historyPages = [
        [
          TransferEvent(
            id: 'deposit',
            from: 'qzMain',
            to: teamMultisig.accountId,
            amount: oneToken * BigInt.from(4800),
            timestamp: _now.subtract(const Duration(days: 6)),
            fee: BigInt.one,
            blockNumber: 1,
            blockHash: '0xblock',
          ),
        ],
      ];
    await _openTeam(tester, chain);

    final rows = [
      for (final row in tester.widgetList<ActivityRowView>(
        find.descendant(of: find.byType(ActivityPanel), matching: find.byType(ActivityRowView)),
      ))
        row.row.label,
    ];
    expect(rows, [_l10n.activityTxProposalExecuted, _l10n.activityTxProposalCancelled, _l10n.activityTxReceived]);
  });
}
