import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide DecodedCallView;
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/decoded_call_view.dart';

/// Shared card layout for indexed and pending multisig proposal rows.
class ProposalListTile extends ConsumerWidget {
  final BigInt amount;
  final String recipientAddress;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool highlighted;

  /// The proposal's decoded call, when the indexer supplied its bytes.
  ///
  /// Proposals are not always transfers, so when this is present the row names
  /// the actual call instead of rendering a non-transfer as "0 tokens to ''".
  final DecodedCall? call;

  final bool callUndecodable;

  const ProposalListTile({
    super.key,
    required this.amount,
    required this.recipientAddress,
    required this.trailing,
    this.onTap,
    this.highlighted = false,
    this.call,
    this.callUndecodable = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatAmount = ref.watch(txAmountDisplayProvider);
    final decoded = call;
    final headline = decoded == null
        ? null
        : DecodedCallHeadline.of(decoded, amountText: (token) => formatAmount(token, isSend: true).primaryAmount);
    final amountText = callUndecodable
        ? l10n.multisigProposalInvalid
        : (headline?.primary ?? formatAmount(amount, isSend: true).primaryAmount);
    final recipient = headline == null
        ? (recipientAddress.isEmpty ? null : AddressFormattingService.formatAddress(recipientAddress))
        : headline.recipient;
    final subtitle = callUndecodable
        ? null
        : (recipient != null ? l10n.multisigProposalToAddress(recipient) : headline?.palletSubtitle);

    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: highlighted ? colors.semanticGlacier.useOpacity(0.15) : colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amountText,
                  style: text.amountRow.copyWith(color: callUndecodable ? colors.semanticEmber : colors.textContent),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.caption.copyWith(color: colors.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    if (onTap == null) return content;

    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ProposalListTile(
      amount: pending.amount,
      recipientAddress: pending.recipient,
      highlighted: true,
      onTap: onTap,
      trailing: Text(l10n.activityTxProposing, style: text.labelChip.copyWith(color: colors.semanticGlacier)),
    );
  }
}
