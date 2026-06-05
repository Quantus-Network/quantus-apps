import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Shows a read-only detail sheet for a multisig [proposal].
///
/// Signing is not yet wired: the action button is disabled and a note explains
/// the current state (already signed, or signing coming soon).
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final currentBlock = ref.watch(multisigCurrentBlockProvider).value;
    final didApprove = proposal.didApprove(msig.myMemberAccountId);

    return BottomSheetContainer(
      title: l10n.multisigProposalTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          _AmountSection(proposal: proposal),
          const SizedBox(height: 20),
          _ProposalDetailRow(
            colors: colors,
            label: l10n.multisigProposalStatusLabel,
            valueWidget: _statusChip(l10n, colors, text, currentBlock),
          ),
          const SizedBox(height: 8),
          DottedBorder(
            dashLength: 3,
            gapLength: 8,
            color: colors.borderButton.useOpacity(0.5),
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 8),
          _summary(l10n, colors, text, fmt, currentBlock),
          const SizedBox(height: 24),
          _signers(l10n, colors, text),
          const SizedBox(height: 24),
          _signSection(l10n, colors, text, didApprove),
          const SizedBox(height: 24),
          Center(
            child: _ExplorerLink(proposal: proposal, colors: colors, text: text),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatBalance(AppLocalizations l10n, NumberFormattingService fmt, BigInt value) {
    return l10n.commonAmountBalance(
      fmt.formatBalance(value, maxDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
  }

  Widget _summary(
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    NumberFormattingService fmt,
    int? currentBlock,
  ) {
    final recipient = AddressFormattingService.formatActivityDetailAddress(proposal.recipient);
    final expiryText = currentBlock != null
        ? DatetimeFormattingService.formatTxDateTime(MultisigService().blockToTime(proposal.expiryBlock, currentBlock))
        : l10n.multisigProposalToAddress('#${proposal.expiryBlock}');

    return Column(
      children: [
        _ProposalDetailRow(colors: colors, label: l10n.activityDetailTo, value: recipient),
        _ProposalDetailRow(colors: colors, label: l10n.multisigProposalExpiresLabel, value: expiryText, valueFlex: 4),
        _ProposalDetailRow(
          colors: colors,
          label: l10n.multisigProposalProposerLabel,
          value: AddressFormattingService.formatActivityDetailAddress(proposal.proposer),
        ),
        _ProposalDetailRow(
          colors: colors,
          label: l10n.multisigProposalThresholdLabel,
          value: l10n.multisigThresholdOf(proposal.threshold, proposal.signerCount),
        ),
        _ProposalDetailRow(
          colors: colors,
          label: l10n.multisigProposalApprovalsLabel,
          value: l10n.multisigApprovalsOf(proposal.approvalCount, proposal.threshold),
        ),
        _ProposalDetailRow(
          colors: colors,
          label: l10n.multisigProposalFeeRowLabel,
          value: _formatBalance(l10n, fmt, proposal.palletFee),
        ),
        _ProposalDetailRow(
          colors: colors,
          label: l10n.multisigProposalDepositLabel,
          value: _formatBalance(l10n, fmt, proposal.deposit),
        ),
        if (proposal.networkFee != null && proposal.networkFee != BigInt.zero)
          _ProposalDetailRow(
            colors: colors,
            label: l10n.activityDetailNetworkFee,
            value: _formatBalance(l10n, fmt, proposal.networkFee!),
          ),
      ],
    );
  }

  Widget _signers(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.multisigProposalSignersLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 12),
          ...msig.signers.map((s) {
            final approved = proposal.approvals.contains(s);
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

  Widget _signSection(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text, bool didApprove) {
    final note = didApprove ? l10n.multisigProposalAlreadySignedNote : l10n.multisigProposalSigningSoonNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuantusButton.simple(
          label: didApprove ? l10n.multisigAlreadyApproved : l10n.multisigProposalSignButton,
          variant: ButtonVariant.success,
          isDisabled: true,
          onTap: null,
        ),
        const SizedBox(height: 12),
        Text(
          note,
          textAlign: TextAlign.center,
          style: text.detail?.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }

  Widget _statusChip(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text, int? currentBlock) {
    final isExpired = currentBlock != null && proposal.expired(currentBlock);
    final (label, color) = switch (proposal.status) {
      MultisigProposalStatus.active =>
        isExpired ? (l10n.multisigStatusExpired, colors.textTertiary) : (l10n.multisigStatusActive, colors.checksum),
      MultisigProposalStatus.approved =>
        isExpired ? (l10n.multisigStatusExpired, colors.textTertiary) : (l10n.multisigStatusApproved, colors.checksum),
      MultisigProposalStatus.executed => (l10n.multisigStatusExecuted, colors.success),
      MultisigProposalStatus.cancelled => (l10n.multisigStatusCancelled, colors.textError),
      MultisigProposalStatus.removed => (l10n.multisigStatusRemoved, colors.textError),
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

class _ProposalDetailRow extends StatelessWidget {
  final AppColorsV2 colors;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final int valueFlex;

  const _ProposalDetailRow({
    required this.colors,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueFlex = 3,
  }) : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    final text = context.themeText;
    final labelStyle = text.transactionDetailRowLabel?.copyWith(color: colors.textTertiary);
    final valueStyle = text.transactionDetailRowValue?.copyWith(color: Colors.white.withValues(alpha: 0.8));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(
            flex: valueFlex,
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ?? Text(value!, style: valueStyle, textAlign: TextAlign.right, softWrap: true),
            ),
          ),
        ],
      ),
    );
  }
}
