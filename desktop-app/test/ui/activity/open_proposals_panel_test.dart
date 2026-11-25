import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/multisig_activity.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

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

  /// A proposal whose call is the sample call [name].
  MultisigProposal callProposal(String name) => MultisigProposal(
    entityId: 'call-$name',
    id: 9,
    multisigAddress: teamMultisig.accountId,
    proposer: 'qzOther',
    createdAt: _now.subtract(const Duration(hours: 1)),
    updatedAt: _now.subtract(const Duration(hours: 1)),
    pallet: name.split('.').first,
    call: name.split('.').last,
    recipient: '',
    amount: BigInt.zero,
    callRaw: corpusCall(name),
    expiryBlock: 1300000,
    approvals: const [],
    deposit: oneToken,
    status: MultisigProposalStatus.active,
    threshold: teamMultisig.threshold,
    signerCount: teamMultisig.signers.length,
  );

  Finder inPanel(Finder finder) => find.descendant(of: find.byType(OpenProposalsPanel), matching: finder);

  testOnMac('a row of a proposal that moves nothing names its call where the amount stands, and its runtime name '
      'where the recipient does', (tester) async {
    final open = callProposal('ReversibleTransfers.set_high_security');
    await _openTeam(tester, FakeSendChain()..openProposals = [open]);

    expect(inPanel(find.text('Set high security')), findsOne);
    expect(inPanel(find.text(open.decodedCall!.displayTitle)), findsOne);
    expect(inPanel(find.textContaining('0 ${AppConstants.tokenSymbol}')), findsNothing);
    expect(inPanel(find.text(_l10n.activityTxTo)), findsNothing);
  });

  testOnMac('a row of a proposal this wallet cannot read says Invalid proposal in ember, and names nothing else', (
    tester,
  ) async {
    await _openTeam(tester, FakeSendChain()..openProposals = [callProposal('System.remark')]);

    final words = tester.widget<Text>(inPanel(find.text(_l10n.multisigProposalInvalid)));
    expect(words.style?.color, tester.element(find.byType(OpenProposalsPanel)).colorsV3.semanticEmber);
    expect(inPanel(find.textContaining('0 ${AppConstants.tokenSymbol}')), findsNothing);
    expect(inPanel(find.text(_l10n.activityTxTo)), findsNothing);
  });

  // Two approvals are few circles, ten the most circles, eleven the fewest
  // drawn as the bar. The widths are the wide and tight forms' least, and a
  // brief one whose line just holds the rest of the row.
  for (final needed in [2, ApprovalMarks.mostCircles, ApprovalMarks.mostCircles + 1]) {
    for (final (form, width) in [
      (ActivityRowForm.wide, ActivityRowForm.wideFrom),
      (ActivityRowForm.tight, ActivityRowForm.tightFrom),
      (ActivityRowForm.brief, 400.0),
    ]) {
      testWidgets(
        '$needed-of-$needed approvals fit a ${form.name} row $width wide: the count whole, the marks beside it',
        (tester) async {
          useFakeCheckphrases(fakeCheckphrase);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [settingsServiceProvider.overrideWithValue(FakeSettingsService())],
              child: Builder(
                builder: (context) => MaterialApp(
                  theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: width,
                        child: OpenProposalRowView(
                          id: 'proposal',
                          amount: oneToken * BigInt.from(1250),
                          recipient: _bob,
                          wait: ProposalWait.signed,
                          approved: needed,
                          needed: needed,
                          form: form,
                          l10n: _l10n,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: 'nothing overflows');
          final row = tester.getRect(find.byType(OpenProposalRowView));
          final count = tester.getRect(find.text(_l10n.desktopProposeCountOf(needed, needed)));
          final marks = tester.getRect(find.byType(ApprovalMarks));
          expect(row.left <= marks.left && marks.right <= count.left && count.right <= row.right, isTrue);
        },
      );
    }
  }

  // The calls that move nothing with the longest names, at each form's least width.
  for (final name in ['ReversibleTransfers.set_high_security', 'Multisig.create_multisig']) {
    for (final (form, width) in [
      (ActivityRowForm.wide, ActivityRowForm.wideFrom),
      (ActivityRowForm.tight, ActivityRowForm.tightFrom),
      (ActivityRowForm.brief, 400.0),
    ]) {
      testWidgets('$name fits a ${form.name} row $width wide', (tester) async {
        useFakeCheckphrases(fakeCheckphrase);
        final call = MultisigProposal.decodeProposalCall(corpusCall(name));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [settingsServiceProvider.overrideWithValue(FakeSettingsService())],
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: OpenProposalRowView(
                        id: 'proposal',
                        amount: BigInt.zero,
                        recipient: '',
                        call: call,
                        wait: ProposalWait.proposed,
                        approved: 1,
                        needed: 2,
                        form: form,
                        l10n: _l10n,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'nothing overflows');
        expect(find.text(call.humanCall), findsOne);
      });
    }
  }

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
