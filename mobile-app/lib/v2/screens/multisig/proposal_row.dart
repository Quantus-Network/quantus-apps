import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/multisig_activity.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/v2/components/proposal_list_tile.dart';

class ProposalRow extends ConsumerWidget {
  final MultisigProposal proposal;

  /// Local accounts that are members of this multisig.
  ///
  /// Used so the row reflects multi-signer devices correctly (e.g. still
  /// "Proposed" when only one of two local signers has approved).
  final List<String> localSignerIds;
  final VoidCallback? onTap;

  const ProposalRow({super.key, required this.proposal, required this.localSignerIds, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final wait = proposalWaitOf(
      proposal,
      localSignerIds: localSignerIds,
      approvals: ref.watch(pendingMultisigApprovalsProvider),
      executions: ref.watch(pendingMultisigExecutionsProvider),
      cancellations: ref.watch(pendingMultisigCancellationsProvider),
    );
    final pendingLabel = switch (wait) {
      ProposalWait.executing => l10n.activityTxExecuting,
      ProposalWait.approving => l10n.activityTxApproving,
      ProposalWait.cancelling => l10n.activityTxCancelling,
      ProposalWait.signed || ProposalWait.proposed || ProposalWait.closed => null,
    };
    final isSigned = wait == ProposalWait.signed;

    return ProposalListTile(
      amount: proposal.amount,
      recipientAddress: proposal.recipient,
      call: proposal.decodedCall,
      callUndecodable: proposal.hasUndecodableCall,
      highlighted: pendingLabel != null,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (pendingLabel != null)
            Text(pendingLabel, style: text.labelChip.copyWith(color: colors.semanticGlacier))
          else
            _statusChip(l10n, colors, text),
          if (isSigned || wait == ProposalWait.proposed) ...[
            const SizedBox(height: 6),
            QuantusBadge(
              label: isSigned ? l10n.multisigStatusApproved : l10n.multisigStatusProposed,
              tone: isSigned ? BadgeTone.sage : BadgeTone.glacier,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    if (proposal.isOpen) {
      return Text(
        '${proposal.approvalCount}/${proposal.threshold}',
        style: text.amountRow.copyWith(color: colors.textContent),
      );
    }
    final label = switch (proposal.status) {
      MultisigProposalStatus.executed => l10n.multisigStatusExecuted,
      MultisigProposalStatus.cancelled => l10n.multisigStatusCancelled,
      MultisigProposalStatus.removed => l10n.multisigStatusRemoved,
      MultisigProposalStatus.unknown => l10n.multisigStatusUnknown,
      _ => l10n.multisigStatusActive,
    };
    final tone = switch (proposal.status) {
      MultisigProposalStatus.executed => BadgeTone.sage,
      MultisigProposalStatus.cancelled => BadgeTone.ember,
      MultisigProposalStatus.removed => BadgeTone.ember,
      _ => BadgeTone.neutral,
    };
    return QuantusBadge(label: label, tone: tone);
  }
}
