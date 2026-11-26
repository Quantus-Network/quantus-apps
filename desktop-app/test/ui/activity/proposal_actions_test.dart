import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
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
import 'package:wallet_core/services/multisig_approval_polling_service.dart';
import 'package:wallet_core/services/multisig_cancellation_polling_service.dart';
import 'package:wallet_core/services/multisig_execution_polling_service.dart';
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
/// actions under way, on [chain] when given.
Future<void> _openProposal(
  WidgetTester tester,
  MultisigProposal proposal, {
  List<Account> accounts = const [mainAccount],
  void Function(ProviderContainer container)? pending,
  ApprovalAvailability approval = ApprovalAvailability.available,
  FakeSendChain? chain,
}) async {
  final isOpen = !proposal.isTerminal;
  chain ??= FakeSendChain();
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

bool _offered(SheetButton? button) => button != null && !button.isDisabled;

String? _note(WidgetTester tester) {
  final found = _inPanel(find.byKey(ProposalActionsBar.noteKey));
  if (found.evaluate().isEmpty) return null;
  return tester.widget<Text>(found).data;
}

void _approving(ProviderContainer container, String approver) => container
    .read(pendingMultisigApprovalsProvider.notifier)
    .add(
      PendingMultisigApprovalEvent.create(
        multisigAddress: _team.accountId,
        proposalId: 1,
        approverId: approver,
        recipient: _bob,
        amount: oneToken,
      ),
    );

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

    testOnMac('proposed by another account here: Cancel Proposal too', (tester) async {
      await _openProposal(tester, _proposal(proposer: 'qzSavings'), accounts: const [mainAccount, savingsAccount]);

      expect(_offered(_button(tester, ProposalActionsBar.cancelKey)), isTrue);
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
      ('to approve', _proposal(expiryBlock: _expired), _l10n.multisigProposalExpiredNote),
      ('to execute', _ready(expiryBlock: _expired), _l10n.multisigProposalExpiredNote),
    ]) {
      testOnMac('expired, $what: unavailable, with its note', (tester) async {
        await _openProposal(tester, proposal);

        expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
        expect(_note(tester), note);
      });
    }

    testOnMac('no signer of it here: Approve unavailable, with the no-signer note', (tester) async {
      await _openProposal(tester, _proposal(), accounts: const [tradingAccount]);

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
      expect(_note(tester), _l10n.multisigNoSignerHereNote);
    });

    testOnMac('an approval from here under way, another account here still to approve: Cancel unavailable, with the '
        'note that it waits', (tester) async {
      await _openProposal(
        tester,
        _proposal(proposer: 'qzMain'),
        accounts: const [mainAccount, savingsAccount],
        pending: (c) => _approving(c, 'qzSavings'),
      );

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isTrue);
      expect(_offered(_button(tester, ProposalActionsBar.cancelKey)), isFalse);
      expect(_note(tester), _l10n.multisigCancelWaitsNote);
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

  testOnMac('an execution the indexer shows: Execute is not offered again while the proposals are read again', (
    tester,
  ) async {
    final chain = FakeSendChain();
    await _openProposal(tester, _ready(), chain: chain);
    final container = _container(tester);
    const hash = '0xexecuted';
    final pending = PendingMultisigExecutionEvent.create(
      multisigAddress: _team.accountId,
      proposalId: 1,
      executorId: 'qzMain',
      recipient: _bob,
      amount: oneToken,
    ).copyWith(extrinsicHash: hash);
    container.read(pendingMultisigExecutionsProvider.notifier).add(pending);
    container.read(multisigExecutionPollingServiceProvider).startPolling(_team, pending);
    await tester.pumpAndSettle();
    expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);

    final executed = _ready().copyWith(status: MultisigProposalStatus.executed);
    chain.proposalsById[1] = executed;
    chain.indexedExecutions[hash] = MultisigProposalExecutedEvent(
      id: 'executed',
      executorId: 'qzMain',
      multisigAddress: _team.accountId,
      recipient: _bob,
      amount: oneToken,
      proposalId: 1,
      approvers: const ['qzOther', 'qzSavings'],
      result: 'success',
      timestamp: DateTime.now(),
      blockNumber: 2,
      blockHash: '0xblock',
    );
    final held = chain.holdOpenProposals = Completer<void>();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse, reason: 'while the list is read');

    chain
      ..openProposals = const []
      ..pastProposals = [executed];
    held.complete();
    await tester.pumpAndSettle();

    expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isFalse);
    expect(container.read(pendingMultisigExecutionsProvider), isEmpty);
  });

  // A multisig's activity waits for its history too: until that is read, the
  // proposal open is answered for by its lists (n13's review of #829).
  group('with the history not read yet', () {
    const hash = '0xaction';
    final at = DateTime.now();

    for (final (name, before, after, track, indexed)
        in <
          (
            String,
            MultisigProposal,
            MultisigProposal,
            void Function(ProviderContainer container),
            void Function(FakeSendChain chain),
          )
        >[
          (
            'an execution',
            _ready(),
            _ready().copyWith(status: MultisigProposalStatus.executed),
            (container) {
              final pending = PendingMultisigExecutionEvent.create(
                multisigAddress: _team.accountId,
                proposalId: 1,
                executorId: 'qzMain',
                recipient: _bob,
                amount: oneToken,
              ).copyWith(extrinsicHash: hash);
              container.read(pendingMultisigExecutionsProvider.notifier).add(pending);
              container.read(multisigExecutionPollingServiceProvider).startPolling(_team, pending);
            },
            (chain) => chain.indexedExecutions[hash] = MultisigProposalExecutedEvent(
              id: 'executed',
              executorId: 'qzMain',
              multisigAddress: _team.accountId,
              recipient: _bob,
              amount: oneToken,
              proposalId: 1,
              approvers: const ['qzOther', 'qzSavings'],
              result: 'success',
              timestamp: at,
              blockNumber: 2,
              blockHash: '0xblock',
            ),
          ),
          (
            'an approval',
            _proposal(),
            _proposal(status: MultisigProposalStatus.approved, approvals: const ['qzOther', 'qzMain']),
            (container) {
              final pending = PendingMultisigApprovalEvent.create(
                multisigAddress: _team.accountId,
                proposalId: 1,
                approverId: 'qzMain',
              ).copyWith(extrinsicHash: hash);
              container.read(pendingMultisigApprovalsProvider.notifier).add(pending);
              container.read(multisigApprovalPollingServiceProvider).startPolling(_team, pending);
            },
            (chain) => chain.indexedApprovals[hash] = MultisigProposalApprovedEvent(
              id: 'approved',
              approverId: 'qzMain',
              multisigAddress: _team.accountId,
              recipient: _bob,
              amount: oneToken,
              proposalId: 1,
              approvalsCount: 2,
              timestamp: at,
              blockNumber: 2,
              blockHash: '0xblock',
            ),
          ),
          (
            'a cancellation',
            _proposal(proposer: 'qzMain'),
            _proposal(proposer: 'qzMain', status: MultisigProposalStatus.cancelled),
            (container) {
              final pending = PendingMultisigCancellationEvent.create(
                multisigAddress: _team.accountId,
                proposalId: 1,
                proposerId: 'qzMain',
                recipient: _bob,
                amount: oneToken,
              ).copyWith(extrinsicHash: hash);
              container.read(pendingMultisigCancellationsProvider.notifier).add(pending);
              container.read(multisigCancellationPollingServiceProvider).startPolling(_team, pending);
            },
            (chain) => chain.indexedCancellations[hash] = MultisigProposalCancelledEvent(
              id: 'cancelled',
              proposerId: 'qzMain',
              multisigAddress: _team.accountId,
              recipient: _bob,
              amount: oneToken,
              proposalId: 1,
              timestamp: at,
              blockNumber: 2,
              blockHash: '0xblock',
            ),
          ),
        ]) {
      testOnMac('$name the indexer shows: the proposal open turns to what the lists now say, and what it did is '
          'not offered again', (tester) async {
        final chain = FakeSendChain()..holdHistory = Completer<void>();
        await _openProposal(tester, before, chain: chain);
        final container = _container(tester);
        track(container);
        await tester.pumpAndSettle();

        chain.proposalsById[1] = after;
        indexed(chain);
        if (after.isTerminal) {
          chain
            ..openProposals = const []
            ..pastProposals = [after];
        } else {
          chain.openProposals = [after];
        }
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        expect(container.read(pendingMultisigExecutionsProvider), isEmpty);
        expect(container.read(pendingMultisigApprovalsProvider), isEmpty);
        expect(container.read(pendingMultisigCancellationsProvider), isEmpty);
        expect(chain.holdHistory!.isCompleted, isFalse, reason: 'the history is still not read');
        expect((container.read(openedActivityViewProvider) as OpenedProposal?)?.proposal.status, after.status);
        expect(_inPanel(find.text(_l10n.multisigApproveButton)), findsNothing);
        if (after.isTerminal) {
          expect(_button(tester, ProposalActionsBar.primaryKey), isNull);
          expect(_button(tester, ProposalActionsBar.cancelKey), isNull);
        }

        chain.holdHistory!.complete();
        await tester.pumpAndSettle();
      });
    }
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

    testOnMac('that proposed it, not the member: Cancel unavailable, with the note naming it', (tester) async {
      await _openProposal(tester, _proposal(proposer: 'qzVault'), accounts: const [mainAccount, vaultAccount]);

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isTrue);
      expect(_offered(_button(tester, ProposalActionsBar.cancelKey)), isFalse);
      expect(_note(tester), _l10n.desktopProposalKeystoneCancel(vaultAccount.name));
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

    testOnMac('as this device\'s member, beside an account that signs here: Execute offered', (tester) async {
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
          accounts: const [vaultAccount, savingsAccount],
          settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(vaultTeam), multisigs: [vaultTeam]),
          balances: oneTokenEach,
          chain: chain,
        ),
      );
      await tester.tap(find.byType(OpenProposalRowView));
      await tester.pumpAndSettle();

      expect(_offered(_button(tester, ProposalActionsBar.primaryKey)), isTrue);
      expect(_note(tester), isNull);
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
