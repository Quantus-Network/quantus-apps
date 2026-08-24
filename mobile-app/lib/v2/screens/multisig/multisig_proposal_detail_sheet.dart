import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide DecodedCallView;
import 'package:resonance_network_wallet/v2/components/dotted_border.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/multisig_local_signers.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/decoded_call_view.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/components/multisig_expiry_value.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_approve_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_cancel_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_execute_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_signer_picker_sheet.dart';

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

/// Opens the proposal detail sheet immediately and resolves the proposal by id.
///
/// Shows a loader inside the sheet while the proposal is fetched, so taps from
/// push notifications (which only carry the multisig and proposal id) land on
/// the detail UI right away instead of waiting for the network round-trip.
void showMultisigProposalDetailSheetById(
  BuildContext context, {
  required MultisigAccount msig,
  required int proposalId,
}) {
  if (context.peekTopRouteName == multisigProposalDetailSheetRouteSettings.name) {
    Navigator.pop(context);
  }

  BottomSheetContainer.show(
    context,
    routeSettings: multisigProposalDetailSheetRouteSettings,
    builder: (_) => _MultisigProposalDetailSheetById(msig: msig, proposalId: proposalId),
  );
}

/// Resolves a proposal by id, showing a loader/error state until it is fetched,
/// then delegates to [_MultisigProposalDetailSheet] for the full detail UI.
class _MultisigProposalDetailSheetById extends ConsumerWidget {
  final MultisigAccount msig;
  final int proposalId;

  const _MultisigProposalDetailSheetById({required this.msig, required this.proposalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final proposalAsync = ref.watch(multisigProposalByIdProvider((msig: msig, id: proposalId)));

    return proposalAsync.when(
      data: (proposal) => proposal == null
          ? BottomSheetContainer(
              title: l10n.multisigProposalTitle,
              child: _message(context, l10n.multisigProposalNotFound),
            )
          : _MultisigProposalDetailSheet(msig: msig, proposal: proposal),
      loading: () => BottomSheetContainer(
        title: l10n.multisigProposalTitle,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: Loader()),
        ),
      ),
      error: (e, _) => BottomSheetContainer(
        title: l10n.multisigProposalTitle,
        child: _message(context, l10n.multisigLoadFailed(e.toString())),
      ),
    );
  }

  Widget _message(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.themeText.smallParagraph?.copyWith(color: context.colors.textTertiary),
        ),
      ),
    );
  }
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

  List<Account> _localSigners(WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return localSignersForMultisig(msig, accounts);
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
    final localSigners = _localSigners(ref);
    final localSignerIds = localSigners.map((a) => a.accountId).toSet();
    final pendingApprovals = ref.watch(pendingMultisigApprovalsProvider);
    final pendingApproverIds = pendingApproverIdsForProposal(
      pendingApprovals,
      msig.accountId,
      liveProposal.id,
      localSignerIds,
    );
    final eligibleApprovers = eligibleApproversForProposal(
      msig,
      liveProposal,
      localSigners,
      pendingApproverIds: pendingApproverIds,
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
    // True only when every local signer has already approved — another local
    // member may still need to sign even if myMemberAccountId already has.
    final allLocalApproved = localSigners.isNotEmpty && localSigners.every((a) => liveProposal.didApprove(a.accountId));
    final hasPendingApproval = pendingApproverIds.isNotEmpty;
    final hasLocalSigner = localSigners.isNotEmpty;
    final isActionable = currentBlock != null && liveProposal.isActionable(currentBlock);

    return BottomSheetContainer(
      title: l10n.multisigProposalTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
          _summary(l10n, fmt, multisigService, currentBlock, liveProposal),
          const SizedBox(height: 24),
          _signers(l10n, colors, text, liveProposal, localSignerIds),
          const SizedBox(height: 24),
          _actionButtons(
            context,
            l10n,
            liveProposal: liveProposal,
            allLocalApproved: allLocalApproved,
            eligibleApprovers: eligibleApprovers,
            hasPendingApproval: hasPendingApproval,
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
            allLocalApproved: allLocalApproved,
            eligibleApprovers: eligibleApprovers,
            hasPendingApproval: hasPendingApproval,
            pendingExecution: pendingExecution,
            pendingCancellation: pendingCancellation,
            hasLocalSigner: hasLocalSigner,
            isActionable: isActionable,
          ),
          Center(
            child: ExplorerLink(
              url: '${AppConstants.explorerEndpoint}/multisig-proposals/${liveProposal.explorerProposalId}',
            ),
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

    // A proposal is not necessarily a transfer, so show its decoded call when the
    // indexer gave us the bytes and fall back to the recipient row otherwise.
    final decoded = liveProposal.decodedCall;

    return Column(
      children: [
        if (!liveProposal.hasUndecodableCall && decoded != null && decoded.summary == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DecodedCallView(call: decoded),
          )
        else if (!liveProposal.hasUndecodableCall)
          DetailSummaryRow(label: l10n.activityDetailTo, value: recipient),
        if (isTerminal)
          DetailSummaryRow(
            label: l10n.multisigProposalAtLabel,
            value: DatetimeFormattingService.formatTxDateTime(liveProposal.updatedAt),
          )
        else
          DetailSummaryRow(
            label: l10n.multisigProposalExpiresLabel,
            valueWidget: MultisigExpiryValue(parts: expiryParts),
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

  Widget _signers(
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    MultisigProposal liveProposal,
    Set<String> localSignerIds,
  ) {
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
            final isYou = localSignerIds.contains(s);
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
    required bool allLocalApproved,
    required List<Account> eligibleApprovers,
    required bool hasPendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    if (liveProposal.hasUndecodableCall ||
        liveProposal.isTerminal ||
        (allLocalApproved && !liveProposal.isReadyToExecute)) {
      return QuantusButton.simple(
        label: l10n.multisigDone,
        variant: ButtonVariant.secondary,
        onTap: () => Navigator.of(context).pop(),
      );
    }

    final Widget primary = liveProposal.isReadyToExecute
        ? _executeButton(
            context,
            l10n,
            liveProposal: liveProposal,
            hasPendingApproval: hasPendingApproval,
            pendingExecution: pendingExecution,
            pendingCancellation: pendingCancellation,
            hasLocalSigner: hasLocalSigner,
            isActionable: isActionable,
          )
        : _approveButton(
            context,
            l10n,
            liveProposal: liveProposal,
            allLocalApproved: allLocalApproved,
            eligibleApprovers: eligibleApprovers,
            hasPendingApproval: hasPendingApproval,
            pendingCancellation: pendingCancellation,
            isActionable: isActionable,
          );

    final cancelButton = _cancelButton(
      context,
      l10n,
      liveProposal: liveProposal,
      pendingCancellation: pendingCancellation,
      hasOtherPendingAction: hasPendingApproval || pendingExecution != null,
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
    required bool allLocalApproved,
    required List<Account> eligibleApprovers,
    required bool hasPendingApproval,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool isActionable,
  }) {
    // A pending cancellation from this device blocks approving, otherwise the
    // two extrinsics race on-chain and one fails with a wasted fee.
    final canApprove = isActionable && eligibleApprovers.isNotEmpty && pendingCancellation == null;
    // Only show the global "Approving…" state when nothing else can still sign.
    final isApprovingOnly = !canApprove && hasPendingApproval && !allLocalApproved;

    final (label, isDisabled, onTap) = switch ((allLocalApproved, isApprovingOnly, canApprove)) {
      (true, _, _) => (l10n.multisigAlreadyApproved, true, null),
      (_, true, _) => (l10n.multisigProposalApprovingLabel, true, null),
      (_, _, true) => (
        l10n.multisigApproveButton,
        false,
        () => _startApprove(context, liveProposal: liveProposal, eligibleApprovers: eligibleApprovers),
      ),
      _ => (l10n.multisigApproveButton, true, null),
    };

    return QuantusButton.simple(label: label, isDisabled: isDisabled, onTap: onTap);
  }

  Future<void> _startApprove(
    BuildContext context, {
    required MultisigProposal liveProposal,
    required List<Account> eligibleApprovers,
  }) async {
    if (eligibleApprovers.isEmpty) return;

    Account? signer = eligibleApprovers.first;
    if (eligibleApprovers.length > 1) {
      signer = await showMultisigSignerPickerSheet(context, accounts: eligibleApprovers);
      if (signer == null || !context.mounted) return;
    }

    if (!context.mounted) return;
    showMultisigApproveConfirmSheet(context, msig: msig, proposal: liveProposal, signer: signer);
  }

  Widget _executeButton(
    BuildContext context,
    AppLocalizations l10n, {
    required MultisigProposal liveProposal,
    required bool hasPendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    final isPending = pendingExecution != null;
    // A pending approval or cancellation from this device blocks executing,
    // otherwise the two extrinsics race on-chain and one fails with a wasted fee.
    final canExecute =
        isActionable && !isPending && !hasPendingApproval && pendingCancellation == null && hasLocalSigner;

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
    required bool allLocalApproved,
    required List<Account> eligibleApprovers,
    required bool hasPendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    final note = _resolveActionNote(
      l10n,
      liveProposal: liveProposal,
      allLocalApproved: allLocalApproved,
      eligibleApprovers: eligibleApprovers,
      hasPendingApproval: hasPendingApproval,
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
    required bool allLocalApproved,
    required List<Account> eligibleApprovers,
    required bool hasPendingApproval,
    required PendingMultisigExecutionEvent? pendingExecution,
    required PendingMultisigCancellationEvent? pendingCancellation,
    required bool hasLocalSigner,
    required bool isActionable,
  }) {
    if (liveProposal.hasUndecodableCall) {
      return '';
    }
    if (liveProposal.status == MultisigProposalStatus.cancelled) {
      return l10n.multisigProposalAlreadyCancelledNote;
    }
    if (liveProposal.status == MultisigProposalStatus.executed) {
      return l10n.multisigProposalAlreadyExecutedNote;
    }

    if (pendingCancellation != null) return l10n.multisigProposalCancellingNote;
    if (pendingExecution != null) return l10n.multisigProposalExecutingNote;
    // Only surface the approving note when no other local account can still sign.
    if (hasPendingApproval && eligibleApprovers.isEmpty) return l10n.multisigProposalApprovingNote;

    if (liveProposal.isReadyToExecute) {
      return switch ((isActionable, hasLocalSigner)) {
        (false, _) => l10n.multisigExecuteUnavailableNote,
        (_, false) => l10n.multisigExecuteUnavailableNote,
        _ => '',
      };
    }

    return switch ((allLocalApproved, isActionable, hasLocalSigner)) {
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
    if (proposal.hasUndecodableCall) {
      return Text(
        ref.watch(l10nProvider).multisigProposalInvalid,
        textAlign: TextAlign.center,
        style: context.themeText.smallTitle?.copyWith(color: context.colors.textError),
      );
    }

    // Only a value-moving proposal has an amount hero; a governance vote or a
    // runtime-upgrade authorisation is named instead of shown as zero.
    final decoded = proposal.decodedCall;
    if (decoded != null && decoded.summary == null) {
      final text = context.themeText;
      final colors = context.colors;
      return Text(
        decoded.displayTitle,
        textAlign: TextAlign.center,
        style: text.smallTitle?.copyWith(color: colors.textPrimary),
      );
    }

    final amount = ref.watch(txAmountDisplayProvider)(proposal.amount, isSend: true, withTokenSymbol: false);

    return AmountDisplayWithConversion(amountDisplay: amount);
  }
}
