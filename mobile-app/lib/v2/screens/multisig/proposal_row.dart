import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ProposalRow extends ConsumerWidget {
  final MultisigProposal proposal;
  final String myAccountId;
  final VoidCallback? onTap;

  const ProposalRow({super.key, required this.proposal, required this.myAccountId, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountText = '${fmt.formatBalance(proposal.amount, maxDecimals: 4)} ${AppConstants.tokenSymbol}';
    final shortAddr = AddressFormattingService.formatAddress(proposal.recipient);
    final didApprove = proposal.didApprove(myAccountId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceDeep,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.borderButton.useOpacity(0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amountText,
                      style: text.paragraph?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontFamily: AppTextTheme.fontFamilySecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'to $shortAddr',
                      style: text.detail?.copyWith(
                        color: colors.textTertiary,
                        fontFamily: AppTextTheme.fontFamilySecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(colors, text),
                  const SizedBox(height: 6),
                  if (proposal.isOpen && didApprove) _approvedPill(colors, text),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(AppColorsV2 colors, AppTextTheme text) {
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
      MultisigProposalStatus.executed => 'APPROVED',
      MultisigProposalStatus.expired => 'EXPIRED',
      MultisigProposalStatus.cancelled => 'CANCELLED',
      _ => proposal.status.name.toUpperCase(),
    };
    final color = switch (proposal.status) {
      MultisigProposalStatus.executed => colors.success,
      MultisigProposalStatus.expired => colors.textTertiary,
      MultisigProposalStatus.cancelled => colors.textError,
      _ => colors.textPrimary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.useOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: text.detail?.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
    );
  }

  Widget _approvedPill(AppColorsV2 colors, AppTextTheme text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: colors.success, borderRadius: BorderRadius.circular(4)),
      child: Text(
        'APPROVED',
        style: text.detail?.copyWith(
          color: colors.background,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
