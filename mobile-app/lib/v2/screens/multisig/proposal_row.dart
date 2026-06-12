import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/v2/components/proposal_list_tile.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ProposalRow extends ConsumerWidget {
  final MultisigProposal proposal;
  final String myAccountId;
  final VoidCallback? onTap;

  const ProposalRow({super.key, required this.proposal, required this.myAccountId, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final didApprove = proposal.didApprove(myAccountId);
    final pendingApprovals = ref.watch(pendingMultisigApprovalsProvider);
    final pendingApproval = findPendingApprovalForProposal(
      pendingApprovals,
      proposal.multisigAddress,
      proposal.id,
      myAccountId,
    );
    final pendingExecutions = ref.watch(pendingMultisigExecutionsProvider);
    final pendingExecution = findPendingExecutionForProposal(
      pendingExecutions,
      proposal.multisigAddress,
      proposal.id,
      myAccountId,
    );
    final pendingCancellations = ref.watch(pendingMultisigCancellationsProvider);
    final pendingCancellation = findPendingCancellationForProposal(
      pendingCancellations,
      proposal.multisigAddress,
      proposal.id,
      myAccountId,
    );
    final isApproving = pendingApproval != null;
    final isExecuting = pendingExecution != null;
    final isCancelling = pendingCancellation != null;
    final isPending = isApproving || isExecuting || isCancelling;

    return ProposalListTile(
      amount: proposal.amount,
      recipientAddress: proposal.recipient,
      highlighted: isPending,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isExecuting)
            Text(
              l10n.activityTxExecuting,
              style: text.detail?.copyWith(color: colors.checksum, fontWeight: FontWeight.w600, letterSpacing: 0.4),
            )
          else if (isApproving)
            Text(
              l10n.activityTxApproving,
              style: text.detail?.copyWith(color: colors.checksum, fontWeight: FontWeight.w600, letterSpacing: 0.4),
            )
          else if (isCancelling)
            Text(
              l10n.activityTxCancelling,
              style: text.detail?.copyWith(color: colors.checksum, fontWeight: FontWeight.w600, letterSpacing: 0.4),
            )
          else
            _statusChip(l10n, colors, text),
          if (proposal.isOpen && !isPending) ...[
            const SizedBox(height: 6),
            if (didApprove) _approvedPill(l10n, colors, text) else _proposedPill(l10n, colors, text),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    if (proposal.isOpen) {
      return Text(
        '${proposal.approvalCount}/${proposal.threshold}',
        style: text.paragraph?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontFamily: AppTextTheme.fontFamilySecondary,
        ),
      );
    }
    final label = switch (proposal.status) {
      MultisigProposalStatus.executed => l10n.multisigStatusExecuted,
      MultisigProposalStatus.cancelled => l10n.multisigStatusCancelled,
      MultisigProposalStatus.removed => l10n.multisigStatusRemoved,
      MultisigProposalStatus.unknown => l10n.multisigStatusUnknown,
      _ => l10n.multisigStatusActive,
    };
    final color = switch (proposal.status) {
      MultisigProposalStatus.executed => colors.success,
      MultisigProposalStatus.cancelled => colors.textError,
      MultisigProposalStatus.removed => colors.textError,
      MultisigProposalStatus.unknown => colors.textTertiary,
      _ => colors.textPrimary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.useOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: text.detail?.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
    );
  }

  Widget _approvedPill(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return _statusPill(
      label: l10n.multisigStatusApproved,
      background: colors.success,
      foreground: colors.background,
      text: text,
    );
  }

  Widget _proposedPill(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return _statusPill(
      label: l10n.multisigStatusProposed,
      background: colors.checksum.useOpacity(0.18),
      foreground: colors.checksum,
      text: text,
    );
  }

  Widget _statusPill({
    required String label,
    required Color background,
    required Color foreground,
    required AppTextTheme text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: text.detail?.copyWith(color: foreground, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }
}
