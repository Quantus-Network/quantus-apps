import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/shared/utils/multisig_local_signers.dart';
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
    final ids = localSignerIds.isEmpty ? const <String>[] : localSignerIds;
    final allLocalApproved = ids.isNotEmpty && ids.every(proposal.didApprove);
    final pendingApprovals = ref.watch(pendingMultisigApprovalsProvider);
    final pendingApproverIds = pendingApproverIdsForProposal(
      pendingApprovals,
      proposal.multisigAddress,
      proposal.id,
      ids,
    );
    final pendingExecutions = ref.watch(pendingMultisigExecutionsProvider);
    PendingMultisigExecutionEvent? pendingExecution;
    for (final id in ids) {
      pendingExecution = findPendingExecutionForProposal(pendingExecutions, proposal.multisigAddress, proposal.id, id);
      if (pendingExecution != null) break;
    }
    final pendingCancellations = ref.watch(pendingMultisigCancellationsProvider);
    PendingMultisigCancellationEvent? pendingCancellation;
    for (final id in ids) {
      pendingCancellation = findPendingCancellationForProposal(
        pendingCancellations,
        proposal.multisigAddress,
        proposal.id,
        id,
      );
      if (pendingCancellation != null) break;
    }
    // Show "Approving" only when every remaining local signer is already in-flight.
    final hasUnsignedLocal = ids.any((id) => !proposal.didApprove(id));
    final isApproving =
        hasUnsignedLocal &&
        pendingApproverIds.isNotEmpty &&
        ids.every((id) {
          return proposal.didApprove(id) || pendingApproverIds.contains(id);
        });
    final isExecuting = pendingExecution != null;
    final isCancelling = pendingCancellation != null;
    final isPending = isApproving || isExecuting || isCancelling;
    final pendingLabel = isExecuting
        ? l10n.activityTxExecuting
        : isApproving
        ? l10n.activityTxApproving
        : isCancelling
        ? l10n.activityTxCancelling
        : null;

    return ProposalListTile(
      amount: proposal.amount,
      recipientAddress: proposal.recipient,
      call: proposal.decodedCall,
      callUndecodable: proposal.hasUndecodableCall,
      highlighted: isPending,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (pendingLabel != null)
            Text(pendingLabel, style: text.labelChip.copyWith(color: colors.semanticGlacier))
          else
            _statusChip(l10n, colors, text),
          if (proposal.isOpen && !isPending) ...[
            const SizedBox(height: 6),
            QuantusBadge(
              label: allLocalApproved ? l10n.multisigStatusApproved : l10n.multisigStatusProposed,
              tone: allLocalApproved ? BadgeTone.sage : BadgeTone.glacier,
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
