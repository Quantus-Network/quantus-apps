import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/chain_status_providers.dart';
import 'package:quantus_desktop_wallet/providers/proposal_action_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/utils/account_utils.dart';
import 'package:wallet_core/utils/multisig_proposal_actions.dart';

/// What this wallet can do with a [proposal] of [msig], before the details of
/// its panel: Approve or Execute, Cancel Proposal for its proposer, and why
/// an action is not offered, by the rules the phone has.
///
/// Desktop signs only with keys it holds: a Keystone account is never the one
/// that acts, and an action only it could do is unavailable, saying so.
/// Neither is one offered where the computer cannot ask for approval.
class ProposalActionsBar extends ConsumerWidget {
  const ProposalActionsBar({super.key, required this.msig, required this.proposal});

  final MultisigAccount msig;
  final MultisigProposal proposal;

  static const primaryKey = Key('proposalActionPrimary');
  static const cancelKey = Key('proposalActionCancel');
  static const noteKey = Key('proposalActionNote');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final actions = proposalActionsOf(
      msig: msig,
      proposal: proposal,
      accounts: accounts,
      currentBlock: ref.watch(latestBlockProvider),
      pendingApprovals: ref.watch(pendingMultisigApprovalsProvider),
      pendingExecutions: ref.watch(pendingMultisigExecutionsProvider),
      pendingCancellations: ref.watch(pendingMultisigCancellationsProvider),
    );

    final open = switch (actions) {
      ProposalOver() => null,
      ProposalOpen open => open,
    };
    if (open == null) {
      // How it ended is the status line's to say.
      final note = switch (actions.note) {
        null || ProposalActionNote.cancelled || ProposalActionNote.executed => null,
        final note => _noteText(l10n, note),
      };
      return note == null ? const SizedBox.shrink() : _bar(context, buttons: const [], note: note);
    }

    final approvalNotSetUp = ref.watch(approvalAvailabilityProvider).value == ApprovalAvailability.notSetUp;
    String? keystoneNote;

    var primaryState = open.primaryState;
    if (primaryState == ProposalActionState.offered) {
      switch (open.primary) {
        case ProposalPrimaryAction.approve:
          if (!open.eligibleApprovers.any((a) => !a.signsWithHardware)) {
            primaryState = ProposalActionState.unavailable;
            keystoneNote = l10n.desktopProposalKeystoneApprove(open.eligibleApprovers.first.name);
          }
        case ProposalPrimaryAction.execute:
          if (!open.executors.any((a) => !a.signsWithHardware)) {
            primaryState = ProposalActionState.unavailable;
            keystoneNote = l10n.desktopProposalKeystoneExecute(open.executors.first.name);
          }
      }
    }

    var cancelState = open.cancel;
    if (cancelState == ProposalActionState.offered) {
      final canceller = open.canceller ?? (throw StateError('Cancel was offered with no proposer in this wallet.'));
      if (canceller.signsWithHardware) {
        cancelState = ProposalActionState.unavailable;
        keystoneNote ??= l10n.desktopProposalKeystoneCancel(canceller.name);
      }
    }

    final offersAny = primaryState == ProposalActionState.offered || cancelState == ProposalActionState.offered;
    final approvalNote = approvalNotSetUp && offersAny ? approvalNotSetUpNote(l10n) : null;
    if (approvalNotSetUp) {
      if (primaryState == ProposalActionState.offered) primaryState = ProposalActionState.unavailable;
      if (cancelState == ProposalActionState.offered) cancelState = ProposalActionState.unavailable;
    }

    void start(MultisigActionKind kind) => ref
        .read(proposalActionTargetProvider.notifier)
        .open(ProposalActionTarget(kind: kind, msig: msig, proposal: proposal));

    final (primaryLabel, inFlightLabel, primaryKind) = switch (open.primary) {
      ProposalPrimaryAction.approve => (
        l10n.multisigApproveButton,
        l10n.multisigProposalApprovingLabel,
        MultisigActionKind.approve,
      ),
      ProposalPrimaryAction.execute => (
        l10n.multisigExecuteButton,
        l10n.multisigProposalExecutingLabel,
        MultisigActionKind.execute,
      ),
    };

    final note = switch (open.note) {
      final note? => _noteText(l10n, note),
      null => keystoneNote ?? approvalNote,
    };

    return _bar(
      context,
      buttons: [
        _button(
          key: primaryKey,
          state: primaryState,
          label: primaryLabel,
          inFlightLabel: inFlightLabel,
          onTap: () => start(primaryKind),
        ),
        if (cancelState case final cancel?)
          _button(
            key: cancelKey,
            state: cancel,
            label: l10n.multisigCancelProposalButton,
            inFlightLabel: l10n.multisigProposalCancellingLabel,
            kind: SheetButtonKind.secondary,
            onTap: () => start(MultisigActionKind.cancel),
          ),
      ],
      note: note,
    );
  }

  Widget _bar(BuildContext context, {required List<Widget> buttons, required String? note}) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (buttons.isNotEmpty)
          Wrap(spacing: 10, runSpacing: 8, children: [for (final button in buttons) UnconstrainedBox(child: button)]),
        if (note != null) ...[
          if (buttons.isNotEmpty) const SizedBox(height: 10),
          Text(
            note,
            key: noteKey,
            style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted),
          ),
        ],
      ],
    ),
  );

  Widget _button({
    required Key key,
    required ProposalActionState state,
    required String label,
    required String inFlightLabel,
    required VoidCallback onTap,
    SheetButtonKind kind = SheetButtonKind.primary,
  }) => SheetButton(
    key: key,
    label: state == ProposalActionState.inFlight ? inFlightLabel : label,
    kind: kind,
    isDisabled: state != ProposalActionState.offered,
    onTap: onTap,
  );

  static String _noteText(AppLocalizations l10n, ProposalActionNote note) => switch (note) {
    ProposalActionNote.cancelled => l10n.multisigProposalAlreadyCancelledNote,
    ProposalActionNote.executed => l10n.multisigProposalAlreadyExecutedNote,
    ProposalActionNote.cancelling => l10n.multisigProposalCancellingNote,
    ProposalActionNote.executing => l10n.multisigProposalExecutingNote,
    ProposalActionNote.approving => l10n.multisigProposalApprovingNote,
    ProposalActionNote.expired => l10n.multisigProposalExpiredNote,
    ProposalActionNote.noSignerHere => l10n.multisigNoSignerHereNote,
    ProposalActionNote.alreadySigned => l10n.multisigProposalAlreadySignedNote,
    ProposalActionNote.cancelWaitsForApproval => l10n.multisigCancelWaitsNote,
  };
}
