import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
  });

  factory TxItemData.from(TransactionEvent tx, String accountId, AppColorsV2 colors, AppLocalizations l10n) {
    final isSend = tx.from == accountId;
    final isPending = tx is PendingTransactionEvent;
    final isScheduled = tx.isReversibleScheduled;
    final isHighlighted = isPending || isScheduled;

    String getLabel() {
      if (isPending && isSend) {
        return l10n.activityTxSending;
      }
      if (isPending && !isSend) {
        return l10n.activityTxReceiving;
      }
      if (isScheduled && isSend) {
        return l10n.activityTxPending;
      }
      if (isScheduled && !isSend) {
        return l10n.activityTxReceiving;
      }
      if (isSend && !isScheduled) {
        return l10n.activityTxSent;
      }

      return l10n.activityTxReceived;
    }

    String getTimeLabel() {
      if (isPending) {
        return l10n.activityTxTimeNow;
      }
      if (isScheduled) {
        return _formatDuration(tx.timeRemaining, l10n);
      }
      return _timeAgo(tx.timestamp, l10n);
    }

    Color getIconBg() {
      if (isHighlighted && !isSend) {
        return colors.txItemIncomingHighlightBg;
      }
      if (isHighlighted && isSend) {
        return colors.txItemOutgoingHighlightBg;
      }
      return Colors.transparent;
    }

    Color getIconColor() {
      if (isHighlighted && !isSend) {
        return colors.success;
      }
      if (isHighlighted && isSend) {
        return colors.checksum;
      }
      return colors.txItemIconDefault;
    }

    Color getLabelColor() {
      if (isHighlighted && !isSend) {
        return colors.success;
      }
      if (isHighlighted && isSend) {
        return colors.checksum;
      }

      return colors.textPrimary;
    }

    Color getAmountColor() {
      if (!isSend) {
        return colors.success;
      }

      if (isHighlighted && isSend) {
        return colors.checksum;
      }

      return colors.textPrimary;
    }

    Color getBorderColor() {
      if (isHighlighted && !isSend) {
        return colors.txItemIncomingHighlightBorder;
      }
      if (isHighlighted && isSend) {
        return colors.txItemOutgoingHighlightBorder;
      }
      return colors.txItemBorderDefault;
    }

    return TxItemData(
      label: getLabel(),
      timeLabel: getTimeLabel(),
      iconBg: getIconBg(),
      iconColor: getIconColor(),
      labelColor: getLabelColor(),
      amountColor: getAmountColor(),
      borderColor: getBorderColor(),
      isSend: isSend,
      amount: tx.amount,
      counterpartyAddr: AddressFormattingService.formatAddress(isSend ? tx.to : tx.from, prefix: 5, postFix: 3),
    );
  }
}

Widget buildTxItem(
  TransactionEvent tx,
  TxItemData data,
  AppColorsV2 colors,
  AppTextTheme text,
  AppLocalizations l10n, {
  required String formattedAmount,
  required bool isLastItem,
  VoidCallback? onTap,
}) {
  final directionLabel = data.isSend ? l10n.activityTxTo : l10n.activityTxFrom;

  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: data.borderColor, width: 1.5),
                ),
                child: Transform.rotate(
                  angle: data.isSend ? 3.14159 : 0,
                  child: Icon(Icons.arrow_downward_rounded, size: 16, color: data.iconColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.label, style: text.paragraph?.copyWith(color: data.labelColor)),
                    const SizedBox(height: 2),
                    Text(data.timeLabel, style: text.detail?.copyWith(color: colors.textTertiary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedAmount,
                    style: text.paragraph?.copyWith(
                      color: data.amountColor,
                      fontFamily: AppTextTheme.fontFamilySecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$directionLabel: ${data.counterpartyAddr}',
                    style: text.detail?.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLastItem) Divider(color: colors.txItemSeparator, height: 1),
      ],
    ),
  );
}

String _formatDuration(Duration d, AppLocalizations l10n) {
  final days = d.inDays.toString().padLeft(2, '0');
  final hours = (d.inHours % 24).toString().padLeft(2, '0');
  final mins = (d.inMinutes % 60).toString().padLeft(2, '0');
  return l10n.activityTxTimeRemaining(days, hours, mins);
}

String _timeAgo(DateTime timestamp, AppLocalizations l10n) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return l10n.activityTxTimeNow;
  if (diff.inMinutes < 60) return l10n.activityTxTimeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.activityTxTimeHoursAgo(diff.inHours);
  return l10n.activityTxTimeDaysAgo(diff.inDays);
}

String dateGroupLabel(DateTime date, AppLocalizations l10n, String localeName) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final txDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(txDay).inDays;
  if (diff == 0) return l10n.activityDateToday;
  if (diff == 1) return l10n.activityDateYesterday;
  return DatetimeFormattingService.formatDateGroupLabel(date, localeName);
}
