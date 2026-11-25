import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide DecodedCallView;
import 'package:resonance_network_wallet/v2/components/dotted_border.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:wallet_core/utils/multisig_local_signers.dart';
import 'package:wallet_core/utils/multisig_proposal_actions.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/decoded_call_view.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/components/multisig_expiry_value.dart';
import 'package:resonance_network_wallet/v2/components/multisig_signer_list_tile.dart';
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
          style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final currentBlock = ref.watch(multisigCurrentBlockProvider).value;
    final multisigService = ref.watch(multisigServiceProvider);
    final liveProposal = _resolveLiveProposal(ref);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final localSignerIds = localSignersForMultisig(msig, accounts).map((a) => a.accountId).toSet();
    final actions = proposalActionsOf(
      msig: msig,
      proposal: liveProposal,
      accounts: accounts,
      currentBlock: currentBlock,
      pendingApprovals: ref.watch(pendingMultisigApprovalsProvider),
      pendingExecutions: ref.watch(pendingMultisigExecutionsProvider),
      pendingCancellations: ref.watch(pendingMultisigCancellationsProvider),
    );

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
            valueWidget: _statusChip(l10n, currentBlock, liveProposal),
          ),
          const SizedBox(height: 8),
          DottedBorder(
            dashLength: 3,
            gapLength: 8,
            color: colors.borderHairline,
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 8),
          _summary(ref, l10n, fmt, multisigService, currentBlock, liveProposal),
          const SizedBox(height: 24),
          _signers(context, l10n, liveProposal, localSignerIds),
          const SizedBox(height: 24),
          _actionButtons(context, l10n, liveProposal: liveProposal, actions: actions),
          const SizedBox(height: 24),
          _actionNote(context, l10n, actions.note),
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
    WidgetRef ref,
    AppLocalizations l10n,
    NumberFormattingService fmt,
    MultisigService multisigService,
    int? currentBlock,
    MultisigProposal liveProposal,
  ) {
    final recipient = liveProposal.recipient;
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
          DetailSummaryRow(label: l10n.activityDetailTo, value: recipient, checkphraseAddress: liveProposal.recipient),
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
          value: liveProposal.proposer,
          checkphraseAddress: liveProposal.proposer,
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
    BuildContext context,
    AppLocalizations l10n,
    MultisigProposal liveProposal,
    Set<String> localSignerIds,
  ) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.multisigProposalSignersLabel, style: text.labelData.copyWith(color: colors.textMuted)),
          const SizedBox(height: 12),
          ...msig.signers.map((s) {
            final approved = liveProposal.approvals.contains(s);
            return MultisigSignerListTile(
              accountId: s,
              isYou: localSignerIds.contains(s),
              youLabel: l10n.multisigYouLabel,
              leading: Icon(
                approved ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: approved ? colors.semanticSage : colors.textMuted,
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
    required ProposalActions actions,
  }) {
    final open = switch (actions) {
      ProposalOver() => null,
      ProposalOpen open => open,
    };
    if (open == null) {
      return QuantusButton.simple(
        label: l10n.multisigDone,
        variant: ButtonVariant.staged,
        onTap: () => Navigator.of(context).pop(),
      );
    }

    final Widget primary = switch (open.primary) {
      ProposalPrimaryAction.execute => _actionButton(
        open.primaryState,
        label: l10n.multisigExecuteButton,
        inFlightLabel: l10n.multisigProposalExecutingLabel,
        onTap: () => showMultisigExecuteConfirmSheet(context, msig: msig, proposal: liveProposal),
      ),
      ProposalPrimaryAction.approve => _actionButton(
        open.primaryState,
        label: l10n.multisigApproveButton,
        inFlightLabel: l10n.multisigProposalApprovingLabel,
        onTap: () => _startApprove(context, liveProposal: liveProposal, eligibleApprovers: open.eligibleApprovers),
      ),
    };

    final cancel = open.cancel;
    if (cancel == null) return primary;
    final canceller = open.canceller ?? (throw StateError('Cancel was offered with no proposer in this wallet.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        const SizedBox(height: 12),
        _actionButton(
          cancel,
          label: l10n.multisigCancelProposalButton,
          inFlightLabel: l10n.multisigProposalCancellingLabel,
          variant: ButtonVariant.danger,
          onTap: () => showMultisigCancelConfirmSheet(context, msig: msig, proposal: liveProposal, signer: canceller),
        ),
      ],
    );
  }

  Widget _actionButton(
    ProposalActionState state, {
    required String label,
    required String inFlightLabel,
    required VoidCallback onTap,
    ButtonVariant variant = ButtonVariant.primary,
  }) {
    final offered = state == ProposalActionState.offered;
    return QuantusButton.simple(
      label: state == ProposalActionState.inFlight ? inFlightLabel : label,
      variant: variant,
      isDisabled: !offered,
      onTap: offered ? onTap : null,
    );
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

  Widget _actionNote(BuildContext context, AppLocalizations l10n, ProposalActionNote? note) {
    if (note == null) return const SizedBox.shrink();

    final text = switch (note) {
      ProposalActionNote.cancelled => l10n.multisigProposalAlreadyCancelledNote,
      ProposalActionNote.executed => l10n.multisigProposalAlreadyExecutedNote,
      ProposalActionNote.cancelling => l10n.multisigProposalCancellingNote,
      ProposalActionNote.executing => l10n.multisigProposalExecutingNote,
      ProposalActionNote.approving => l10n.multisigProposalApprovingNote,
      ProposalActionNote.executeUnavailable => l10n.multisigExecuteUnavailableNote,
      ProposalActionNote.alreadySigned => l10n.multisigProposalAlreadySignedNote,
      ProposalActionNote.approveUnavailable => l10n.multisigApproveUnavailableNote,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted),
      ),
    );
  }

  Widget _statusChip(AppLocalizations l10n, int? currentBlock, MultisigProposal liveProposal) {
    final isExpired = currentBlock != null && liveProposal.expired(currentBlock);
    final (label, tone) = switch (liveProposal.status) {
      MultisigProposalStatus.active =>
        isExpired ? (l10n.multisigStatusExpired, BadgeTone.sand) : (l10n.multisigStatusActive, BadgeTone.glacier),
      MultisigProposalStatus.approved =>
        isExpired ? (l10n.multisigStatusExpired, BadgeTone.sand) : (l10n.multisigStatusApproved, BadgeTone.glacier),
      MultisigProposalStatus.executed => (l10n.multisigStatusExecuted, BadgeTone.sage),
      MultisigProposalStatus.cancelled => (l10n.multisigStatusCancelled, BadgeTone.ember),
      MultisigProposalStatus.removed => (l10n.multisigStatusRemoved, BadgeTone.ember),
      MultisigProposalStatus.unknown => (l10n.multisigStatusUnknown, BadgeTone.neutral),
    };
    return QuantusBadge(label: label, tone: tone);
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
        style: context.themeTextV3.titleScreen.copyWith(color: context.colorsV3.semanticEmber),
      );
    }

    // Only a value-moving proposal has an amount hero; a governance vote or a
    // runtime-upgrade authorisation is named instead of shown as zero.
    final decoded = proposal.decodedCall;
    if (decoded != null && decoded.summary == null) {
      final text = context.themeTextV3;
      final colors = context.colorsV3;
      return Text(
        decoded.displayTitle,
        textAlign: TextAlign.center,
        style: text.titleScreen.copyWith(color: colors.textContent),
      );
    }

    final amount = ref.watch(txAmountDisplayProvider)(proposal.amount, isSend: true, withTokenSymbol: false);

    return AmountDisplayWithConversion(amountDisplay: amount);
  }
}
