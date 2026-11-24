import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/proposal_action_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/proposal_actions.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _now = DateTime.now();
const _bob = 'qzBob4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu';

/// The chain is at block 1250000 (the fake's), so a proposal expiring at
/// 1249000 is past its expiry.
const _expired = 1249000;

/// Main, Savings and the Keystone Vault all sign for it, with another
/// signer's; two approvals are needed. This device's member is Main.
final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzSavings', 'qzVault', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

MultisigProposal _proposal({
  MultisigProposalStatus status = MultisigProposalStatus.active,
  List<String> approvals = const ['qzOther'],
  String proposer = 'qzOther',
  int expiryBlock = 1284220,
  List<int>? callRaw,
}) => MultisigProposal(
  entityId: 'proposal-1',
  id: 1,
  multisigAddress: _team.accountId,
  proposer: proposer,
  createdAt: _now.subtract(const Duration(hours: 5)),
  updatedAt: _now.subtract(const Duration(hours: 5)),
  pallet: 'Balances',
  call: 'transfer_allow_death',
  recipient: _bob,
  amount: oneToken * BigInt.from(250),
  callRaw: callRaw == null ? null : Uint8List.fromList(callRaw),
  expiryBlock: expiryBlock,
  approvals: approvals,
  deposit: oneToken,
  status: status,
  threshold: _team.threshold,
  signerCount: _team.signers.length,
);

/// Approved by two other signers, waiting to be executed.
MultisigProposal _ready({String proposer = 'qzOther', int expiryBlock = 1284220}) => _proposal(
  status: MultisigProposalStatus.approved,
  approvals: const ['qzOther', 'qzSavings'],
  proposer: proposer,
  expiryBlock: expiryBlock,
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inPanel(Finder finder) => find.descendant(of: find.byType(ActivityInspector), matching: finder);

/// Opens the team with [proposal] as its only proposal, open or past, and
/// opens that, with [accounts] in the wallet and [pending] this device's
/// actions under way.
Future<void> _openProposal(
  WidgetTester tester,
  MultisigProposal proposal, {
  List<Account> accounts = const [mainAccount],
  void Function(ProviderContainer container)? pending,
  ApprovalAvailability approval = ApprovalAvailability.available,
}) async {
  final isOpen = !proposal.isTerminal;
  final chain = FakeSendChain();
  if (isOpen) {
    chain.openProposals = [proposal];
  } else {
    chain.pastProposals = [proposal];
  }
  await pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: accounts,
      settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(_team), multisigs: [_team]),
      balances: oneTokenEach,
      chain: chain,
      approval: FakeUserApproval()..availabilityAnswer = approval,
    ),
  );
  pending?.call(_container(tester));
  await tester.pumpAndSettle();
  if (isOpen) {
    await tester.tap(find.byType(OpenProposalRowView));
  } else {
    await tester.tap(find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == proposal.entityId));
  }
  await tester.pumpAndSettle();
}

SheetButton? _button(WidgetTester tester, Key key) {
  final found = _inPanel(find.byKey(key));
  if (found.evaluate().isEmpty) return null;
  return tester.widget<SheetButton>(found);
}

bool _offered(SheetButton? button) => button != null && !button.isDisabled && button.onTap != null;

String? _note(WidgetTester tester) {
  final found = _inPanel(find.byKey(ProposalActionsBar.noteKey));
  if (found.evaluate().isEmpty) return null;
  return tester.widget<Text>(found).data;
}

void _approving(ProviderContainer container, String approver) => container
    .read(pendingMultisigApprovalsProvider.notifier)
    .add(PendingMultisigApprovalEvent.create(multisigAddress: _team.accountId, proposalId: 1, approverId: approver));

void _executing(ProviderContainer container) => container
    .read(pendingMultisigExecutionsProvider.notifier)
    .add(
      PendingMultisigExecutionEvent.create(
        multisigAddress: _team.accountId,
        proposalId: 1,
        executorId: 'qzMain',
        recipient: _bob,
        amount: oneToken,
      ),
    );

void _cancelling(ProviderContainer container) => container
    .read(pendingMultisigCancellationsProvider.notifier)
    .add(
      PendingMultisigCancellationEvent.create(
        multisigAddress: _team.accountId,
        proposalId: 1,
        proposerId: 'qzMain',
        recipient: _bob,
        amount: oneToken,
      ),
    );

void main() {
  group('what is offered', () {
    testOnMac('one account still to approve: Approve, above the details, and no Cancel for another\'s proposal', (
      tester,
    ) async {
      await _openProposal(tester, _proposal());

      final approve = _button(tester, ProposalActionsBar.primaryKey);
      expect(approve?.label, _l10n.multisigApproveButton);
      expect(_offered(approve), isTrue);
      expect(_button(tester, ProposalActionsBar.cancelKey), isNull);
      expect(_note(tester), isNull);
      expect(
        tester.getTopLeft(_inPanel(find.byKey(ProposalActionsBar.primaryKey))).dy,
        lessThan(tester.getTopLeft(_inPanel(find.text(_l10n.activityTxMultisigLabel))).dy),
      );
    });

    testOnMac('proposed by this device\'s member: Cancel Proposal too', (tester) async {
      await _openProposal(tester, _proposal(proposer: 'qzMain'));

      final cancel = _button(tester, ProposalActionsBar.cancelKey);
      expect(cancel?.label, _l10n.multisigCancelProposalButton);
      expect(_offered(cancel), isTrue);
    });

    testOnMac('approved: Execute', (tester) async {
      await _openProposal(tester, _ready());

      final execute = _button(tester, ProposalActionsBar.primaryKey);
      expect(execute?.label, _l10n.multisigExecuteButton);
      expect(_offered(execute), isTrue);
    });
  });

  group('under way, and the notes', () {
    for (final (what, ready, pending, label, note) in [
      (
        'an approval',
        false,
        (ProviderContainer c) => _approving(c, 'qzMain'),
        _l10n.multisigProposalApprovingLabel,
        _l10n.multisigProposalApprovingNote,
      ),
      ('an execution', true, _executing, _l10n.multisigProposalExecutingLabel, _l10n.multisigProposalExecutingNote),
    ]) {
      testOnMac('$what under way: its label, unavailable, with the phone\'s note', (tester) async {
        await _openProposal(tester, ready ? _ready() : _proposal(), pending: pending);

        final primary = _button(tester, ProposalActionsBar.primaryKey);
        expect(primary?.label, label);
        expect(_offered(primary), isFalse);
        expect(_note(tester), note);
      });
    }

    testOnMac('a cancellation under way: "Cancelling…", unavailable, with the phone\'s note', (tester) async {
      await _openProposal(tester, _proposal(proposer: 'qzMain'), pending: _cancelling);

      final cancel = _button(tester, ProposalActionsBar.cancelKey);
      expect(cancel?.label, _l10n.multisigProposalCancellingLabel);
      expect(_offered(cancel), isFalse);
      expect(_note(tester), _l10n.multisigProposalCancellingNote);
    });

    testOnMac('every account here has approved: no buttons, the already-signed note', (tester) async {
      await _openProposal(tester, _proposal(approvals: const ['qzMain']));

      expect(_button(tester, ProposalActionsBar.primaryKey), isNull);
      expect(_note(tester), _l10n.multisigProposalAlreadySignedNote);
    });

    for (final (what, proposal, note) in [
      ('to approve', _proposal(expiryBlock: _expired), _l10n.multisigApproveUnavailableNote),
      ('to execute', _ready(expiryBlock: _expired), _l10n.multisigExecuteUnavailableNote),
    ]) {
      testOnMac('expired, $what: unavailable, with its note', (tester) async {
        await _openProposal(tester, proposal);

        expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
        expect(_note(tester), note);
      });
    }

    testOnMac('no signer of it here: Approve unavailable, with the unavailable note', (tester) async {
      await _openProposal(tester, _proposal(), accounts: const [tradingAccount]);

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
      expect(_note(tester), _l10n.multisigApproveUnavailableNote);
    });

    for (final status in [MultisigProposalStatus.executed, MultisigProposalStatus.cancelled]) {
      testOnMac('${status.name}: no buttons and no note, its status says it', (tester) async {
        await _openProposal(tester, _proposal(status: status, proposer: 'qzMain'));

        expect(_button(tester, ProposalActionsBar.primaryKey), isNull);
        expect(_button(tester, ProposalActionsBar.cancelKey), isNull);
        expect(_note(tester), isNull);
      });
    }

    testOnMac('a call this wallet cannot read: no buttons', (tester) async {
      await _openProposal(tester, _proposal(callRaw: [...corpusCall('Balances.transfer_allow_death'), 0]));

      expect(_button(tester, ProposalActionsBar.primaryKey), isNull);
      expect(_button(tester, ProposalActionsBar.cancelKey), isNull);
    });
  });

  group('a Keystone account', () {
    testOnMac('the only one still to approve: Approve unavailable, with the note naming it', (tester) async {
      await _openProposal(
        tester,
        _proposal(approvals: const ['qzOther', 'qzMain']),
        accounts: const [mainAccount, vaultAccount],
      );

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
      expect(_note(tester), _l10n.desktopProposalKeystoneApprove(vaultAccount.name));
    });

    testOnMac('beside one that signs here: Approve offered', (tester) async {
      await _openProposal(tester, _proposal(), accounts: const [mainAccount, vaultAccount]);

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isTrue);
      expect(_note(tester), isNull);
    });

    testOnMac('as this device\'s member, on an approved proposal: Execute unavailable, with its note', (tester) async {
      final vaultTeam = MultisigAccount(
        name: 'Team',
        accountId: 'qzTeam',
        signers: _team.signers,
        threshold: 2,
        nonce: BigInt.zero,
        myMemberAccountId: 'qzVault',
      );
      final chain = FakeSendChain()..openProposals = [_ready()];
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [vaultAccount],
          settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(vaultTeam), multisigs: [vaultTeam]),
          balances: oneTokenEach,
          chain: chain,
        ),
      );
      await tester.tap(find.byType(OpenProposalRowView));
      await tester.pumpAndSettle();

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
      expect(_note(tester), _l10n.desktopProposalKeystoneExecute(vaultAccount.name));
    });
  });

  testOnMac('no login password set up: the actions are unavailable, with the note to set one', (tester) async {
    await _openProposal(tester, _proposal(proposer: 'qzMain'), approval: ApprovalAvailability.notSetUp);

    expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
    expect(_offered(_button(tester, ProposalActionsBar.cancelKey)), isFalse);
    expect(_note(tester), approvalNotSetUpNote(_l10n));
  });

  group('pressing an action opens its sheet, for this proposal', () {
    for (final (kind, proposal, key) in [
      (MultisigActionKind.approve, _proposal(), ProposalActionsBar.primaryKey),
      (MultisigActionKind.execute, _ready(), ProposalActionsBar.primaryKey),
      (MultisigActionKind.cancel, _proposal(proposer: 'qzMain'), ProposalActionsBar.cancelKey),
    ]) {
      testOnMac(kind.name, (tester) async {
        await _openProposal(tester, proposal);

        await tester.tap(_inPanel(find.byKey(key)));
        await tester.pumpAndSettle();

        final container = _container(tester);
        expect(container.read(shellSheetProvider), ShellSheet.proposalAction);
        final target = container.read(proposalActionTargetProvider);
        expect(target?.kind, kind);
        expect(target?.msig.accountId, _team.accountId);
        expect(target?.proposal.id, proposal.id);
      });
    }
  });
}
