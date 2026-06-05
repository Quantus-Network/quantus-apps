import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Shared card layout for indexed and pending multisig proposal rows.
class ProposalListTile extends ConsumerWidget {
  final BigInt amount;
  final String recipientAddress;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool highlighted;

  const ProposalListTile({
    super.key,
    required this.amount,
    required this.recipientAddress,
    required this.trailing,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final amountText = ref.watch(txAmountDisplayProvider)(amount, isSend: true).primaryAmount;
    final shortAddr = AddressFormattingService.formatAddress(recipientAddress);

    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? colors.txItemOutgoingHighlightBorder : colors.borderButton.useOpacity(0.4),
        ),
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
                  l10n.multisigProposalToAddress(shortAddr),
                  style: text.detail?.copyWith(
                    color: colors.textTertiary,
                    fontFamily: AppTextTheme.fontFamilySecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: content),
    );
  }
}

/// Pending proposal row shown while waiting for indexer confirmation.
class PendingProposalRow extends ConsumerWidget {
  final PendingMultisigProposalEvent pending;
  final VoidCallback? onTap;

  const PendingProposalRow({super.key, required this.pending, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    return ProposalListTile(
      amount: pending.amount,
      recipientAddress: pending.recipient,
      highlighted: true,
      onTap: onTap,
      trailing: Text(
        l10n.activityTxProposing,
        style: text.detail?.copyWith(color: colors.checksum, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      ),
    );
  }
}
