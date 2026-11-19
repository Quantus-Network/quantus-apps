import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';

class TxItemData {
  final String label;
  final String timeLabel;
  final Color iconBg;
  final Color iconColor;
  final Color labelColor;
  final Color amountColor;
  final Color borderColor;
  final bool isSend;
  final BigInt amount;
  final String counterpartyAddr;
  final bool hideAmount;
  final IconData? customIcon;

  /// Prefix of the counterparty line: null for To/From by direction, empty
  /// to show [counterpartyAddr] on its own.
  final String? counterpartyDirectionLabel;

  const TxItemData({
    required this.label,
    required this.timeLabel,
    required this.iconBg,
    required this.iconColor,
    required this.labelColor,
    required this.amountColor,
    required this.borderColor,
    required this.isSend,
    required this.amount,
    required this.counterpartyAddr,
    this.hideAmount = false,
    this.customIcon,
    this.counterpartyDirectionLabel,
  });

  /// The row [tx] makes in the activity of [accountId], as wallet_core
  /// decides it ([activityRowOf]), in the phone's colours and pictures, with
  /// addresses shortened.
  factory TxItemData.from(
    TransactionEvent tx,
    String accountId,
    AppColorsV3 colors,
    AppLocalizations l10n, {
    bool isPrivate = false,
  }) {
    final row = activityRowOf(tx, accountId: accountId, l10n: l10n, isPrivate: isPrivate);
    final (accent, fill, stroke) = switch (row.highlight) {
      ActivityHighlight.arriving => (colors.semanticSage, _sageFill(colors), _sageStroke(colors)),
      ActivityHighlight.leaving => (colors.semanticGlacier, glacierFill(colors), glacierStroke(colors)),
      ActivityHighlight.none => (colors.textContent, Colors.transparent, colors.borderHairline),
    };
    final counterparty = row.counterparty;

    return TxItemData(
      label: row.label,
      timeLabel: row.timeLabel,
      iconBg: fill,
      iconColor: accent,
      labelColor: accent,
      // What arrives is always in sage, settled or not.
      amountColor: row.isSend ? accent : colors.semanticSage,
      borderColor: stroke,
      isSend: row.isSend,
      amount: row.amount,
      hideAmount: row.hidesAmount,
      customIcon: switch (row.icon) {
        ActivityIcon.direction => null,
        ActivityIcon.proposal => Icons.how_to_vote_outlined,
        ActivityIcon.multisig => Icons.groups_outlined,
      },
      counterpartyAddr: switch (counterparty) {
        ActivityAccount(:final address) ||
        ActivityMultisig(:final address) => AddressFormattingService.formatAddress(address, prefix: 5, postFix: 3),
        ActivityUnnamedCounterparty() => counterparty.name(l10n),
      },
      // To or From follow the direction ([buildTxItem]); the others say
      // their own, or nothing.
      counterpartyDirectionLabel: switch (counterparty) {
        ActivityAccount() || ActivityEncryptedSender() || ActivityMiningReward() => null,
        ActivityMultisig() || ActivityAggregatedBatch() => counterparty.prefix(l10n),
      },
    );
  }
}

/// Amount text for a transaction row.
///
/// [isHidden] is passed down by the screen that owns the hide-balances toggle;
/// the amount formatter has no notion of hidden balances.
String txItemAmountText(TxItemData data, TxAmountFormatter format, {bool isHidden = false}) {
  if (isHidden) return hiddenAmountText;
  if (data.hideAmount) return '—';

  return format(data.amount, isSend: data.isSend).primaryAmount;
}

Widget buildTxItem(
  TransactionEvent tx,
  TxItemData data,
  AppColorsV3 colors,
  AppTextThemeV3 text,
  AppRadiusV3 radius,
  AppLocalizations l10n, {
  required String formattedAmount,
  required bool isLastItem,
  Key? itemKey,
  VoidCallback? onTap,
}) {
  final directionLabel = data.counterpartyDirectionLabel ?? (data.isSend ? l10n.activityTxTo : l10n.activityTxFrom);

  return GestureDetector(
    key: itemKey,
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: radius.xsBorder,
                  border: Border.all(color: data.borderColor, width: 1.5),
                ),
                child: data.customIcon != null
                    ? Icon(data.customIcon, size: 14, color: data.iconColor)
                    : Transform.rotate(
                        angle: data.isSend ? 3.14159 : 0,
                        child: Icon(Icons.arrow_downward_rounded, size: 14, color: data.iconColor),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.label, style: text.bodyLarge.copyWith(color: data.labelColor)),
                    const SizedBox(height: 8),
                    Text(data.timeLabel, style: text.caption.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formattedAmount, style: text.bodyLarge.copyWith(color: data.amountColor)),
                  const SizedBox(height: 8),
                  Text(
                    directionLabel.isEmpty ? data.counterpartyAddr : '$directionLabel: ${data.counterpartyAddr}',
                    style: text.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLastItem) Divider(color: colors.borderHairline, height: 1),
      ],
    ),
  );
}

Color _sageFill(AppColorsV3 colors) => colors.semanticSage.useOpacity(0.08);

Color _sageStroke(AppColorsV3 colors) => colors.semanticSage.useOpacity(0.15);

/// Fill and stroke of a pending row's icon box, shared with the swap row.
Color glacierFill(AppColorsV3 colors) => colors.semanticGlacier.useOpacity(0.08);

Color glacierStroke(AppColorsV3 colors) => colors.semanticGlacier.useOpacity(0.15);
