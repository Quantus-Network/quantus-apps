import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/multisig_expiry_value.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/detail_summary_row.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_approve_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_cancel_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_execute_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Shows proposal detail with approve or execute actions for eligible signers.
void showMultisigProposalDetailSheet(
  BuildContext context, {
  required MultisigAccount msig,
  required MultisigProposal proposal,
}) {
  if (context.peekTopRouteName == multisigProposalDetailSheetRouteSettings.name) {
    Navigator.pop(context);
  }

  BottomSheetContainer.show(
    context,
    routeSettings: multisigProposalDetailSheetRouteSettings,
    builder: (_) => _MultisigProposalDetailSheet(msig: msig, proposal: proposal),
  );
}

class _MultisigProposalDetailSheet extends ConsumerWidget {
  final MultisigAccount msig;
  final MultisigProposal proposal;

  const _MultisigProposalDetailSheet({required this.msig, required this.proposal});

  MultisigProposal _resolveLiveProposal(WidgetRef ref) {
    MultisigProposal? findMatch(Iterable<MultisigProposal> proposals) {
      for (final p in proposals) {
        if (p.id == proposal.id && p.multisigAddress == proposal.multisigAddress) {
          return p;
        }
      }
      return null;
    }

    final open = ref.watch(multisigOpenProposalsProvider(msig)).value;
    if (open != null) {
      final match = findMatch(open);
      if (match != null) return match;
    }

    final past = ref.watch(multisigPastProposalsProvider(msig)).value;
    if (past != null) {
      final match = findMatch(past);
      if (match != null) return match;
    }

    return proposal;
  }

  bool _hasLocalSigner(WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return accounts.any((a) => a.accountId == msig.myMemberAccountId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final currentBlock = ref.watch(multisigCurrentBlockProvider).value;
    final multisigService = ref.watch(multisigServiceProvider);
    final liveProposal = _resolveLiveProposal(ref);
    final pendingApprovals = ref.watch(pendingMultisigApprovalsProvider);
    final pendingApproval = findPendingApprovalForProposal(
      pendingApprovals,
      msig.accountId,
      liveProposal.id,
      msig.myMemberAccountId,
    );
    final pendingExecutions = ref.watch(pendingMultisigExecutionsProvider);
    final pendingExecution = findPendingExecutionForProposal(
      pendingExecutions,
      msig.accountId,
      liveProposal.id,
      msig.myMemberAccountId,
    );
    final pendingCancellations = ref.watch(pendingMultisigCancellationsProvider);
    final pendingCancellation = findPendingCancellationForProposal(
      pendingCancellations,
      msig.accountId,
      liveProposal.id,
      msig.myMemberAccountId,
    );
    final didApprove = liveProposal.didApprove(msig.myMemberAccountId);
    final hasLocalSigner = _hasLocalSigner(ref);
    final isActionable = currentBlock != null && liveProposal.isActionable(currentBlock);

    return BottomSheetContainer(
      title: l10n.multisigProposalTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          _AmountSection(proposal: liveProposal),
          const SizedBox(height: 20),
          DetailSummaryRow(
            label: l10n.multisigProposalStatusLabel,
            valueWidget: _statusChip(l10n, colors, text, currentBlock, liveProposal),
          ),
          const SizedBox(height: 8),
          DottedBorder(
            dashLength: 3,
            gapLength: 8,
            color: colors.borderButton.useOpacity(0.5),
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 8),
          _summary(l10n, colors, text, fmt, multisigService, currentBlock, liveProposal),
          const SizedBox(height: 24),
          _signers(l10n, colors, text, liveProposal),
          const SizedBox(height: 24),
          _actionButtons(
            context,
            l10n,
            liveProposal: liveProposal,
            didApprove: didApprove,
            pendingApproval: pendingApproval,
            pendingExecution: pendingExecution,
            pendingCancellation: pendingCancellation,
            hasLocalSigner: hasLocalSigner,
            isActionable: isActionable,
          ),
          const SizedBox(height: 24),
          _actionNote(
            l10n,
            colors,
            text,
            liveProposal: liveProposal,
            didApprove: didApprove,
            pendingApproval: pendingApproval,
            pendingExecution: pendingExecution,
            pendingCancellation: pendingCancellation,
            hasLocalSigner: hasLocalSigner,
            isActionable: isActionable,
          ),
          Center(
            child: _ExplorerLink(proposal: liveProposal, colors: colors, text: text),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatBalance(AppLocalizations l10n, NumberFormattingService fmt, BigInt value) {
    return l10n.commonAmountBalance(
      fmt.formatBalance(value, smartDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
  }

  Widget _summary(
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    NumberFormattingService fmt,
    MultisigService multisigService,
    int? currentBlock,
    MultisigProposal liveProposal,
  ) {
    final recipient = AddressFormattingService.formatActivityDetailAddress(liveProposal.recipient);
    final expiryParts = resolveMultisigExpiryParts(
      l10n: l10n,
      expiryBlock: liveProposal.expiryBlock,
      multisigService: multisigService,
      currentBlock: currentBlock,
    );
    final isTerminal = liveProposal.isTerminal;

    return Column(
      children: [
        DetailSummaryRow(label: l10n.activityDetailTo, value: recipient),
        if (isTerminal)
          DetailSummaryRow(
            label: l10n.multisigProposalAtLabel,
            value: DatetimeFormattingService.formatTxDateTime(liveProposal.updatedAt),
          )
        else
          DetailSummaryRow(
            label: l10n.multisigProposalExpiresLabel,
            valueWidget: MultisigExpiryValue(
              parts: expiryParts,
              style: text.transactionDetailRowValue?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
            ),
            valueFlex: 4,
          ),
        DetailSummaryRow(
          label: l10n.multisigProposalProposerLabel,
          value: AddressFormattingService.formatActivityDetailAddress(liveProposal.proposer),
        ),
        DetailSummaryRow(
          label: l10n.multisigProposalThresholdLabel,
          value: l10n.multisigThresholdOf(liveProposal.threshold, liveProposal.signerCount),
        ),
        DetailSummaryRow(
          label: l10n.multisigProposalApprovalsLabel,
          value: l10n.multisigApprovalsOf(liveProposal.approvalCount, liveProposal.threshold),
        ),
        DetailSummaryRow(
          label: l10n.multisigProposalFeeRowLabel,
          value: _formatBalance(l10n, fmt, liveProposal.palletFee),
        ),
        DetailSummaryRow(
          label: l10n.multisigProposalDepositLabel,
          value: _formatBalance(l10n, fmt, liveProposal.deposit),
        ),
        if (liveProposal.networkFee != null && liveProposal.networkFee != BigInt.zero)
          DetailSummaryRow(
            label: l10n.activityDetailNetworkFee,
            value: _formatBalance(l10n, fmt, liveProposal.networkFee!),
          ),
      ],
    );
  }

  Widget _signers(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text, MultisigProposal liveProposal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.multisigProposalSignersLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 12),
          ...msig.signers.map((s) {
            final approved = liveProposal.approvals.contains(s);
            final isYou = s == msig.myMemberAccountId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    approved ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: approved ? colors.success : colors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AddressFormattingService.formatAddress(s),
                      style: text.smallParagraph?.copyWith(
                        color: colors.textPrimary,
                        fontFamily: AppTextTheme.fontFamilySecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isYou)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.useOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.multisigYouLabel,
                        style: text.detail?.copyWith(
                          color: colors.accentOrange,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionButtons(
    BuildContext context,
    AppLocalizations l10n, {
    required MultisigProposal liveProposal,
    required bool didApprove,
    required PendingMultisigApprovalEvent? pendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    if (liveProposal.status == MultisigProposalStatus.executed ||
        liveProposal.status == MultisigProposalStatus.cancelled) {
      return const SizedBox.shrink();
    }

    final Widget primary = liveProposal.isReadyToExecute
        ? _executeButton(
            context,
            l10n,
            liveProposal: liveProposal,
            pendingApproval: pendingApproval,
            pendingExecution: pendingExecution,
            pendingCancellation: pendingCancellation,
            hasLocalSigner: hasLocalSigner,
            isActionable: isActionable,
          )
        : _approveButton(
            context,
            l10n,
            liveProposal: liveProposal,
            didApprove: didApprove,
            pendingApproval: pendingApproval,
            pendingCancellation: pendingCancellation,
            hasLocalSigner: hasLocalSigner,
            isActionable: isActionable,
          );

    final cancelButton = _cancelButton(
      context,
      l10n,
      liveProposal: liveProposal,
      pendingCancellation: pendingCancellation,
      hasOtherPendingAction: pendingApproval != null || pendingExecution != null,
      hasLocalSigner: hasLocalSigner,
      isActionable: isActionable,
    );

    if (cancelButton == null) return primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [primary, const SizedBox(height: 12), cancelButton],
    );
  }

  Widget? _cancelButton(
    BuildContext context,
    AppLocalizations l10n, {
    required MultisigProposal liveProposal,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasOtherPendingAction,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    if (liveProposal.isTerminal) return null;

    final isProposer = liveProposal.proposer == msig.myMemberAccountId;
    if (!isProposer) return null;

    final isPending = pendingCancellation != null;
    final canCancel = isActionable && !isPending && !hasOtherPendingAction && hasLocalSigner;

    final (label, isDisabled, onTap) = switch ((isPending, canCancel)) {
      (true, _) => (l10n.multisigProposalCancellingLabel, true, null),
      (_, true) => (
        l10n.multisigCancelProposalButton,
        false,
        () => showMultisigCancelConfirmSheet(context, msig: msig, proposal: liveProposal),
      ),
      _ => (l10n.multisigCancelProposalButton, true, null),
    };

    return QuantusButton.simple(label: label, variant: ButtonVariant.danger, isDisabled: isDisabled, onTap: onTap);
  }

  Widget _approveButton(
    BuildContext context,
    AppLocalizations l10n, {
    required MultisigProposal liveProposal,
    required bool didApprove,
    required PendingMultisigApprovalEvent? pendingApproval,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    final isPending = pendingApproval != null;
    // A pending cancellation from this device blocks approving, otherwise the
    // two extrinsics race on-chain and one fails with a wasted fee.
    final canApprove = isActionable && !didApprove && !isPending && pendingCancellation == null && hasLocalSigner;

    final (label, isDisabled, onTap) = switch ((didApprove, isPending, canApprove)) {
      (true, _, _) => (l10n.multisigAlreadyApproved, true, null),
      (_, true, _) => (l10n.multisigProposalApprovingLabel, true, null),
      (_, _, true) => (
        l10n.multisigApproveButton,
        false,
        () => showMultisigApproveConfirmSheet(context, msig: msig, proposal: liveProposal),
      ),
      _ => (l10n.multisigApproveButton, true, null),
    };

    return QuantusButton.simple(label: label, isDisabled: isDisabled, onTap: onTap);
  }

  Widget _executeButton(
    BuildContext context,
    AppLocalizations l10n, {
    required MultisigProposal liveProposal,
    required PendingMultisigApprovalEvent? pendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    final isPending = pendingExecution != null;
    // A pending approval or cancellation from this device blocks executing,
    // otherwise the two extrinsics race on-chain and one fails with a wasted fee.
    final canExecute =
        isActionable && !isPending && pendingApproval == null && pendingCancellation == null && hasLocalSigner;

    final (label, isDisabled, onTap) = switch ((isPending, canExecute)) {
      (true, _) => (l10n.multisigProposalExecutingLabel, true, null),
      (_, true) => (
        l10n.multisigExecuteButton,
        false,
        () => showMultisigExecuteConfirmSheet(context, msig: msig, proposal: liveProposal),
      ),
      _ => (l10n.multisigExecuteButton, true, null),
    };

    return QuantusButton.simple(label: label, isDisabled: isDisabled, onTap: onTap);
  }

  Widget _actionNote(
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text, {
    required MultisigProposal liveProposal,
    required bool didApprove,
    required PendingMultisigApprovalEvent? pendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    final note = _resolveActionNote(
      l10n,
      liveProposal: liveProposal,
      didApprove: didApprove,
      pendingApproval: pendingApproval,
      pendingExecution: pendingExecution,
      pendingCancellation: pendingCancellation,
      hasLocalSigner: hasLocalSigner,
      isActionable: isActionable,
    );

    if (note.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        note,
        textAlign: TextAlign.center,
        style: text.detail?.copyWith(color: colors.textTertiary),
      ),
    );
  }

  String _resolveActionNote(
    AppLocalizations l10n, {
    required MultisigProposal liveProposal,
    required bool didApprove,
    required PendingMultisigApprovalEvent? pendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    if (liveProposal.status == MultisigProposalStatus.cancelled) {
      return l10n.multisigProposalAlreadyCancelledNote;
    }
    if (liveProposal.status == MultisigProposalStatus.executed) {
      return l10n.multisigProposalAlreadyExecutedNote;
    }

    if (pendingCancellation != null) return l10n.multisigProposalCancellingNote;
    if (pendingExecution != null) return l10n.multisigProposalExecutingNote;
    if (pendingApproval != null) return l10n.multisigProposalApprovingNote;

    if (liveProposal.isReadyToExecute) {
      return switch ((isActionable, hasLocalSigner)) {
        (false, _) => l10n.multisigExecuteUnavailableNote,
        (_, false) => l10n.multisigExecuteUnavailableNote,
        _ => '',
      };
    }

    return switch ((didApprove, isActionable, hasLocalSigner)) {
      (true, _, _) => l10n.multisigProposalAlreadySignedNote,
      (_, false, _) => l10n.multisigApproveUnavailableNote,
      (_, _, false) => l10n.multisigApproveUnavailableNote,
      _ => '',
    };
  }

  Widget _statusChip(
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    int? currentBlock,
    MultisigProposal liveProposal,
  ) {
    final isExpired = currentBlock != null && liveProposal.expired(currentBlock);
    final (label, color) = switch (liveProposal.status) {
      MultisigProposalStatus.active =>
        isExpired ? (l10n.multisigStatusExpired, colors.textTertiary) : (l10n.multisigStatusActive, colors.checksum),
      MultisigProposalStatus.approved =>
        isExpired ? (l10n.multisigStatusExpired, colors.textTertiary) : (l10n.multisigStatusApproved, colors.checksum),
      MultisigProposalStatus.executed => (l10n.multisigStatusExecuted, colors.success),
      MultisigProposalStatus.cancelled => (l10n.multisigStatusCancelled, colors.textError),
      MultisigProposalStatus.removed => (l10n.multisigStatusRemoved, colors.textError),
      MultisigProposalStatus.unknown => (l10n.multisigStatusUnknown, colors.textTertiary),
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
}

class _AmountSection extends ConsumerWidget {
  final MultisigProposal proposal;

  const _AmountSection({required this.proposal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = ref.watch(txAmountDisplayProvider)(proposal.amount, isSend: true, withQuanSymbol: false);

    return AmountDisplayWithConversion(amountDisplay: amount);
  }
}

class _ExplorerLink extends ConsumerWidget {
  final MultisigProposal proposal;
  final AppColorsV2 colors;
  final AppTextTheme text;

  const _ExplorerLink({required this.proposal, required this.colors, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return GestureDetector(
      onTap: () => openUrl('${AppConstants.explorerEndpoint}/multisig-proposals/${proposal.explorerProposalId}'),
      child: Container(
        padding: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.accentOrange, width: 1)),
        ),
        child: Text(
          l10n.activityDetailViewExplorer,
          style: text.smallParagraph?.copyWith(color: colors.accentOrange, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
