import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/proposal_action_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/activity/proposal_action_sheet.dart';
import 'package:quantus_desktop_wallet/ui/activity/proposal_detail.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/decoded_call_headline.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/multisig_action_confirmations_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _now = DateTime.now();

/// Main and Savings sign for it, and so do the Keystone Vault and another
/// signer; two approvals are needed. This device's member is Main.
final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzSavings', 'qzVault', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

/// The transfer the chain stores for a proposal unless told otherwise.
final _transfer = MultisigProposal.decodeProposalCall(corpusCall('Balances.transfer_allow_death'));
final _sent = _transfer.summary as TransferSummary;

MultisigProposal _proposal({
  MultisigProposalStatus status = MultisigProposalStatus.active,
  List<String> approvals = const ['qzOther'],
  String proposer = 'qzOther',
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
  recipient: _sent.recipient ?? '',
  amount: _sent.amount,
  callRaw: Uint8List.fromList(callRaw ?? corpusCall('Balances.transfer_allow_death')),
  expiryBlock: 1284220,
  approvals: approvals,
  deposit: oneToken,
  status: status,
  threshold: _team.threshold,
  signerCount: _team.signers.length,
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inSheet(Finder finder) => find.descendant(of: find.byType(ProposalActionSheet), matching: finder);

String _money(WidgetTester tester, BigInt amount) {
  final formatting = _container(tester).read(numberFormattingServiceProvider);
  return _l10n.commonAmountBalance(formatting.formatBalance(amount), AppConstants.tokenSymbol);
}

typedef _Sheet = ({FakeSendChain chain, FakeUserApproval approval, List<Uri> opened});

/// Opens the sheet that does [kind] to [proposal], with [accounts] in the
/// wallet.
Future<_Sheet> _open(
  WidgetTester tester,
  MultisigActionKind kind,
  MultisigProposal proposal, {
  List<Account> accounts = const [mainAccount],
  FakeSendChain? chain,
  FakeUserApproval? approval,
}) async {
  final sheet = (chain: chain ?? FakeSendChain(), approval: approval ?? FakeUserApproval(), opened: <Uri>[]);
  sheet.chain.openProposals = [proposal];
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: accounts,
        settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(_team), multisigs: [_team]),
        balances: oneTokenEach,
        chain: sheet.chain,
        approval: sheet.approval,
      ),
      openExternalUrlProvider.overrideWithValue((url) async => sheet.opened.add(url)),
    ],
  );
  await _container(
    tester,
  ).read(proposalActionTargetProvider.notifier).open(ProposalActionTarget(kind: kind, msig: _team, proposal: proposal));
  await tester.pumpAndSettle();
  return sheet;
}

SheetButton _button(WidgetTester tester, Key key) => tester.widget<SheetButton>(_inSheet(find.byKey(key)));

bool _offered(WidgetTester tester, Key key) {
  final button = _button(tester, key);
  return !button.isDisabled;
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(_inSheet(find.byKey(ProposalActionSheet.confirmKey)));
  await tester.pumpAndSettle();
}

/// What the wallet learned of the action sent in [hash].
Future<void> _settle(WidgetTester tester, String hash, MultisigActionConfirmation outcome) async {
  _container(tester).read(multisigActionConfirmationsProvider.notifier).settle(hash, outcome);
  await tester.pumpAndSettle();
}

void main() {
  group('the review', () {
    testOnMac('approve: what it approves, to whom, the multisig, who signs, how far it gets, and who pays the fee', (
      tester,
    ) async {
      await _open(tester, MultisigActionKind.approve, _proposal());

      expect(_inSheet(find.text(_l10n.desktopProposalApproving.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_sent.recipient!)), findsOne);
      for (final label in [_l10n.activityTxMultisigLabel, _l10n.desktopProposalSignsAs, _l10n.swapReviewNetworkFee]) {
        expect(_inSheet(find.text(label)), findsOne, reason: label);
      }
      expect(_inSheet(find.text(mainAccount.name)), findsWidgets);
      expect(
        _inSheet(
          find.text(
            _l10n.desktopProposalApprovalsChange(_l10n.desktopProposeCountOf(1, 2), _l10n.desktopProposeCountOf(2, 2)),
          ),
        ),
        findsOne,
      );
      expect(_inSheet(find.text(_l10n.desktopProposePays)), findsOne);
      expect(_inSheet(find.text(_money(tester, FakeSendChain.usualFee))), findsNWidgets(2));
      expect(_button(tester, ProposalActionSheet.confirmKey).label, _l10n.multisigApproveButton);
      expect(_offered(tester, ProposalActionSheet.confirmKey), isTrue);
    });

    testOnMac('a call that moves nothing: its name and fields stand where the amount would', (tester) async {
      final bytes = corpusCall('ReversibleTransfers.set_high_security');
      final chain = FakeSendChain()..proposalCall = (_) async => bytes;
      await _open(tester, MultisigActionKind.approve, _proposal(callRaw: bytes), chain: chain);

      final call = MultisigProposal.decodeProposalCall(bytes);
      final name = DecodedCallHeadline.of(call, amountText: (_) => throw StateError('moves nothing')).primary;
      expect(_inSheet(find.text(name)), findsOne);
      expect(_inSheet(find.byType(ProposalCallFields)), findsOne);
    });

    testOnMac('while the call is read from the chain: said, and Approve waits for it', (tester) async {
      final held = Completer<List<int>>();
      final chain = FakeSendChain()..proposalCall = (_) => held.future;
      await _open(tester, MultisigActionKind.approve, _proposal(), chain: chain);

      expect(_inSheet(find.text(_l10n.multisigProposalCallLoading)), findsOne);
      expect(_offered(tester, ProposalActionSheet.confirmKey), isFalse);
      expect(chain.actionQuotes, isEmpty, reason: 'the fee waits for the call');

      held.complete(corpusCall('Balances.transfer_allow_death'));
      await tester.pumpAndSettle();

      expect(_inSheet(find.text(_l10n.multisigProposalCallLoading)), findsNothing);
      expect(_offered(tester, ProposalActionSheet.confirmKey), isTrue);
    });

    testOnMac('a reversible transfer: what it is and its window, beside the amount and to whom', (tester) async {
      final bytes = corpusCall('ReversibleTransfers.schedule_transfer_with_delay');
      final chain = FakeSendChain()..proposalCall = (_) async => bytes;
      await _open(tester, MultisigActionKind.approve, _proposal(callRaw: bytes), chain: chain);

      final call = MultisigProposal.decodeProposalCall(bytes);
      expect(call.summary?.reversible, isTrue, reason: 'the sample is a reversible transfer');
      expect(_inSheet(find.text(call.displayTitle)), findsOne);
      expect(_inSheet(find.text('Reversible for')), findsOne);
      expect(_inSheet(find.text('Destination')), findsNothing, reason: 'the recipient is already said');
      expect(_inSheet(find.text('Amount')), findsNothing, reason: 'the amount is already said');
    });

    testOnMac('a call that cannot be read: said in ember, and Approve unavailable', (tester) async {
      final chain = FakeSendChain()..proposalCall = (_) async => throw StateError('not on chain');
      await _open(tester, MultisigActionKind.approve, _proposal(), chain: chain);

      expect(_inSheet(find.text(_l10n.multisigProposalCallUnavailable)), findsOne);
      expect(_offered(tester, ProposalActionSheet.confirmKey), isFalse);
    });

    testOnMac('a fee that cannot be estimated: said, and Approve still offered', (tester) async {
      final chain = FakeSendChain()..actionFee = () async => throw StateError('no fee');
      await _open(tester, MultisigActionKind.approve, _proposal(), chain: chain);

      expect(_inSheet(find.text(_l10n.multisigFeeEstimateUnavailable)), findsOne);
      expect(_offered(tester, ProposalActionSheet.confirmKey), isTrue);
    });

    testOnMac('two accounts here can approve: a choice, the first chosen; the other is priced and approves', (
      tester,
    ) async {
      final sheet = await _open(
        tester,
        MultisigActionKind.approve,
        _proposal(),
        accounts: const [mainAccount, savingsAccount],
      );

      expect(_inSheet(find.byKey(ProposalActionSheet.signerKey('qzMain'))), findsOne);
      expect(_inSheet(find.byKey(ProposalActionSheet.signerKey('qzSavings'))), findsOne);
      expect(sheet.chain.actionQuotes.map((quote) => quote.$2), ['qzMain']);

      await tester.tap(_inSheet(find.byKey(ProposalActionSheet.signerKey('qzSavings'))));
      await tester.pumpAndSettle();
      expect(sheet.chain.actionQuotes.map((quote) => quote.$2), ['qzMain', 'qzSavings']);

      await _confirm(tester);

      expect(sheet.chain.actions.map((action) => (action.$1, action.$2)), [('approve', 'qzSavings')]);
    });

    testOnMac('a Keystone account is not offered as a choice', (tester) async {
      await _open(tester, MultisigActionKind.approve, _proposal(), accounts: const [mainAccount, vaultAccount]);

      expect(_inSheet(find.byKey(ProposalActionSheet.signerKey('qzVault'))), findsNothing);
      expect(_inSheet(find.text(vaultAccount.name)), findsNothing);
    });

    testOnMac('execute: every approval it needs, and Execute', (tester) async {
      await _open(
        tester,
        MultisigActionKind.execute,
        _proposal(status: MultisigProposalStatus.approved, approvals: const ['qzOther', 'qzSavings']),
      );

      expect(_inSheet(find.text(_l10n.desktopProposalExecuting.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposeCountOf(2, 2))), findsOne);
      expect(_button(tester, ProposalActionSheet.confirmKey).label, _l10n.multisigExecuteButton);
    });

    testOnMac('cancel: in ember, the phone\'s sentence, the deposit refunded, Keep or Cancel Proposal', (tester) async {
      await _open(tester, MultisigActionKind.cancel, _proposal(proposer: 'qzMain'));

      expect(_inSheet(find.text(_l10n.desktopProposalCancelling.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_l10n.multisigCancelConfirmBody)), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalDepositRefunded)), findsOne);
      expect(_button(tester, ProposalActionSheet.dismissKey).label, _l10n.multisigCancelConfirmKeep);
      final confirm = _button(tester, ProposalActionSheet.confirmKey);
      expect(confirm.label, _l10n.multisigCancelProposalButton);
      expect(confirm.kind, SheetButtonKind.destructive);
    });
  });

  group('confirming', () {
    testOnMac('a declined approval: still the review, approval required, nothing sent', (tester) async {
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.declined;
      final sheet = await _open(tester, MultisigActionKind.approve, _proposal(), approval: approval);

      await _confirm(tester);

      expect(approval.reasons, [_l10n.multisigApproveAuthReason]);
      expect(_inSheet(find.text(_l10n.multisigAuthRequired)), findsOne);
      expect(sheet.chain.actions, isEmpty);
      expect(_offered(tester, ProposalActionSheet.confirmKey), isTrue);
    });

    testOnMac('no login password set up: Approve unavailable, with the note to set one', (tester) async {
      await _open(
        tester,
        MultisigActionKind.approve,
        _proposal(),
        approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp,
      );

      expect(_offered(tester, ProposalActionSheet.confirmKey), isFalse);
      expect(_inSheet(find.text(approvalNotSetUpNote(_l10n))), findsOne);
    });

    testOnMac('a failed submission: said beside the buttons, and trying again sends it', (tester) async {
      final chain = FakeSendChain()..submitAction = () async => throw StateError('rejected');
      await _open(tester, MultisigActionKind.approve, _proposal(), chain: chain);

      await _confirm(tester);
      expect(_inSheet(find.text(_l10n.multisigApproveFailed)), findsOne);
      expect(chain.actions, isEmpty);

      chain.submitAction = () async => '0xaction';
      await _confirm(tester);

      expect(chain.actions.map((action) => action.$1), ['approve']);
      expect(_inSheet(find.text(_l10n.desktopProposeConfirming.toUpperCase())), findsOne);
    });

    testOnMac('while it is sent, the sheet cannot be closed', (tester) async {
      final held = Completer<String>();
      final chain = FakeSendChain()..submitAction = () => held.future;
      await _open(tester, MultisigActionKind.approve, _proposal(), chain: chain);

      await tester.tap(_inSheet(find.byKey(ProposalActionSheet.confirmKey)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(ProposalActionSheet), findsOne);
      held.complete('0xaction');
      await tester.pumpAndSettle();

      // Once it has gone out, Escape closes the sheet as it closes any.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ProposalActionSheet), findsNothing);
    });
  });

  group('the receipt follows what became of it', () {
    testOnMac('approve: Confirming, then Approved, and it can be executed', (tester) async {
      await _open(tester, MultisigActionKind.approve, _proposal());
      await _confirm(tester);
      final what = _money(tester, _sent.amount);

      expect(_inSheet(find.text(_l10n.desktopProposeConfirming.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalApprovingTitle(what))), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalApprovalWaiting)), findsOne);

      await _settle(tester, '0xaction', MultisigActionConfirmation.confirmed);

      expect(_inSheet(find.text(_l10n.desktopProposalApproved.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalApprovedTitle(what))), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalReadyToExecute)), findsOne);
    });

    testOnMac('approve, short of what it needs: how many more approvals', (tester) async {
      await _open(tester, MultisigActionKind.approve, _proposal(approvals: const []));
      await _confirm(tester);
      await _settle(tester, '0xaction', MultisigActionConfirmation.confirmed);

      expect(_inSheet(find.text(_l10n.desktopProposalApprovalsNeeded(1))), findsOne);
    });

    testOnMac('execute, done by another signer first: said in sand, with what it cost', (tester) async {
      await _open(
        tester,
        MultisigActionKind.execute,
        _proposal(status: MultisigProposalStatus.approved, approvals: const ['qzOther', 'qzSavings']),
      );
      await _confirm(tester);
      await _settle(tester, '0xaction', MultisigActionConfirmation.executedByAnother);

      expect(_inSheet(find.text(_l10n.desktopProposalExecutedByAnother.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalExecutedTitle(_money(tester, _sent.amount)))), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalExecutedByAnotherBody)), findsOne);
    });

    testOnMac('not confirmed: said in ember, with the phone\'s sentence', (tester) async {
      await _open(tester, MultisigActionKind.approve, _proposal());
      await _confirm(tester);
      await _settle(tester, '0xaction', MultisigActionConfirmation.unconfirmed);

      expect(_inSheet(find.text(_l10n.desktopProposeNotConfirmed.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_l10n.multisigApprovalTimeoutToast)), findsOne);
    });

    testOnMac('View in Explorer opens the proposal\'s page; Done closes the sheet', (tester) async {
      final proposal = _proposal();
      final sheet = await _open(tester, MultisigActionKind.approve, proposal);
      await _confirm(tester);

      await tester.tap(_inSheet(find.byKey(ProposalActionSheet.explorerKey)));
      await tester.pumpAndSettle();
      expect(sheet.opened, [
        Uri.parse('${AppConstants.explorerEndpoint}/multisig-proposals/${proposal.explorerProposalId}'),
      ]);

      await tester.tap(_inSheet(find.byKey(ProposalActionSheet.doneKey)));
      await tester.pumpAndSettle();
      expect(find.byType(ProposalActionSheet), findsNothing);
      expect(_container(tester).read(shellSheetProvider), isNull);
    });
  });
}
