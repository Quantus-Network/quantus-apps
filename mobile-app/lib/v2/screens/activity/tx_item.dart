import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
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

  factory TxItemData.from(
    TransactionEvent tx,
    String accountId,
    AppColorsV3 colors,
    AppLocalizations l10n, {
    bool isPrivate = false,
  }) {
    if (tx is PendingMultisigProposalEvent) {
      final recipient = AddressFormattingService.formatAddress(tx.recipient, prefix: 5, postFix: 3);
      return TxItemData(
        label: l10n.activityTxProposing,
        timeLabel: l10n.activityTxTimeNow,
        iconBg: _glacierFill(colors),
        iconColor: colors.semanticGlacier,
        labelColor: colors.semanticGlacier,
        amountColor: colors.semanticGlacier,
        borderColor: _glacierStroke(colors),
        isSend: true,
        amount: tx.amount,
        counterpartyAddr: recipient,
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is MultisigProposalCreatedEvent) {
      final recipient = AddressFormattingService.formatAddress(tx.recipient, prefix: 5, postFix: 3);
      return TxItemData(
        label: l10n.activityTxProposalCreated,
        timeLabel: _timeAgo(tx.timestamp, l10n),
        iconBg: Colors.transparent,
        iconColor: colors.textContent,
        labelColor: colors.textContent,
        amountColor: colors.textContent,
        borderColor: colors.borderHairline,
        isSend: true,
        amount: tx.amount,
        counterpartyAddr: recipient,
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is MultisigProposalApprovedEvent) {
      final recipient = AddressFormattingService.formatAddress(tx.recipient, prefix: 5, postFix: 3);
      final fee = tx.networkFee;
      return TxItemData(
        label: l10n.activityTxProposalApproved,
        timeLabel: _timeAgo(tx.timestamp, l10n),
        iconBg: Colors.transparent,
        iconColor: colors.textContent,
        labelColor: colors.textContent,
        amountColor: colors.textContent,
        borderColor: colors.borderHairline,
        isSend: true,
        amount: fee,
        hideAmount: fee == BigInt.zero,
        counterpartyAddr: recipient,
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is PendingMultisigExecutionEvent) {
      final recipient = AddressFormattingService.formatAddress(tx.recipient, prefix: 5, postFix: 3);
      final fee = tx.memberCost;
      return TxItemData(
        label: l10n.activityTxExecuting,
        timeLabel: l10n.activityTxTimeNow,
        iconBg: _glacierFill(colors),
        iconColor: colors.semanticGlacier,
        labelColor: colors.semanticGlacier,
        amountColor: colors.semanticGlacier,
        borderColor: _glacierStroke(colors),
        isSend: true,
        amount: fee,
        hideAmount: fee == BigInt.zero,
        counterpartyAddr: recipient,
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is MultisigProposalExecutedEvent) {
      final recipient = AddressFormattingService.formatAddress(tx.recipient, prefix: 5, postFix: 3);
      final fee = tx.networkFee;
      return TxItemData(
        label: l10n.activityTxProposalExecuted,
        timeLabel: _timeAgo(tx.timestamp, l10n),
        iconBg: Colors.transparent,
        iconColor: colors.textContent,
        labelColor: colors.textContent,
        amountColor: colors.textContent,
        borderColor: colors.borderHairline,
        isSend: true,
        amount: fee,
        hideAmount: fee == BigInt.zero,
        counterpartyAddr: recipient,
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is PendingMultisigCancellationEvent) {
      final recipient = AddressFormattingService.formatAddress(tx.recipient, prefix: 5, postFix: 3);
      final fee = tx.memberCost;
      return TxItemData(
        label: l10n.activityTxCancelling,
        timeLabel: l10n.activityTxTimeNow,
        iconBg: _glacierFill(colors),
        iconColor: colors.semanticGlacier,
        labelColor: colors.semanticGlacier,
        amountColor: colors.semanticGlacier,
        borderColor: _glacierStroke(colors),
        isSend: true,
        amount: fee,
        hideAmount: fee == BigInt.zero,
        counterpartyAddr: recipient,
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is MultisigProposalCancelledEvent) {
      final recipient = AddressFormattingService.formatAddress(tx.recipient, prefix: 5, postFix: 3);
      final fee = tx.networkFee;
      return TxItemData(
        label: l10n.activityTxProposalCancelled,
        timeLabel: _timeAgo(tx.timestamp, l10n),
        iconBg: Colors.transparent,
        iconColor: colors.textContent,
        labelColor: colors.textContent,
        amountColor: colors.textContent,
        borderColor: colors.borderHairline,
        isSend: true,
        amount: fee,
        hideAmount: fee == BigInt.zero,
        counterpartyAddr: recipient,
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is MultisigProposalEvent) {
      return TxItemData(
        label: l10n.activityTxProposal,
        timeLabel: _timeAgo(tx.timestamp, l10n),
        iconBg: Colors.transparent,
        iconColor: colors.textContent,
        labelColor: colors.textContent,
        amountColor: colors.textContent,
        borderColor: colors.borderHairline,
        isSend: true,
        amount: tx.amount,
        counterpartyAddr: AddressFormattingService.formatAddress(tx.to, prefix: 5, postFix: 3),
        customIcon: Icons.how_to_vote_outlined,
      );
    }

    if (tx is PendingMultisigCreationEvent) {
      final address = AddressFormattingService.formatAddress(tx.multisigAddress, prefix: 5, postFix: 3);
      return TxItemData(
        label: l10n.activityTxMultisigCreating,
        timeLabel: l10n.activityTxTimeNow,
        iconBg: _glacierFill(colors),
        iconColor: colors.semanticGlacier,
        labelColor: colors.semanticGlacier,
        amountColor: colors.semanticGlacier,
        borderColor: _glacierStroke(colors),
        isSend: true,
        amount: tx.totalCost,
        counterpartyAddr: address,
        customIcon: Icons.groups_outlined,
        counterpartyDirectionLabel: l10n.activityTxMultisigLabel,
      );
    }

    if (tx is MultisigCreatedEvent) {
      final address = AddressFormattingService.formatAddress(tx.multisigAddress, prefix: 5, postFix: 3);
      return TxItemData(
        label: l10n.activityTxMultisigCreated,
        timeLabel: _timeAgo(tx.timestamp, l10n),
        iconBg: Colors.transparent,
        iconColor: colors.textContent,
        labelColor: colors.textContent,
        amountColor: colors.textContent,
        borderColor: colors.borderHairline,
        isSend: true,
        amount: tx.totalCost,
        counterpartyAddr: address,
        customIcon: Icons.groups_outlined,
        counterpartyDirectionLabel: l10n.activityTxMultisigLabel,
      );
    }

    final isSend = tx.from == accountId;
    final isPending = tx is PendingTransactionEvent;
    final isScheduled = tx.isReversibleScheduled;
    final isHighlighted = isPending || isScheduled;

    String getLabel() {
      if (isPending && isSend) {
        return isPrivate ? l10n.activityTxPrivatelySending : l10n.activityTxSending;
      }
      if (isPending && !isSend) {
        return isPrivate ? l10n.activityTxPrivatelyReceiving : l10n.activityTxReceiving;
      }
      if (isScheduled && isSend) {
        return l10n.activityTxPending;
      }
      if (isScheduled && !isSend) {
        return isPrivate ? l10n.activityTxPrivatelyReceiving : l10n.activityTxReceiving;
      }
      if (isSend && !isScheduled) {
        return isPrivate ? l10n.activityTxPrivateSent : l10n.activityTxSent;
      }

      return isPrivate ? l10n.activityTxPrivateReceived : l10n.activityTxReceived;
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
        return _sageFill(colors);
      }
      if (isHighlighted && isSend) {
        return _glacierFill(colors);
      }
      return Colors.transparent;
    }

    Color getIconColor() {
      if (isHighlighted && !isSend) {
        return colors.semanticSage;
      }
      if (isHighlighted && isSend) {
        return colors.semanticGlacier;
      }
      return colors.textContent;
    }

    Color getLabelColor() {
      if (isHighlighted && !isSend) {
        return colors.semanticSage;
      }
      if (isHighlighted && isSend) {
        return colors.semanticGlacier;
      }

      return colors.textContent;
    }

    Color getAmountColor() {
      if (!isSend) {
        return colors.semanticSage;
      }

      if (isHighlighted && isSend) {
        return colors.semanticGlacier;
      }

      return colors.textContent;
    }

    Color getBorderColor() {
      if (isHighlighted && !isSend) {
        return _sageStroke(colors);
      }
      if (isHighlighted && isSend) {
        return _glacierStroke(colors);
      }
      return colors.borderHairline;
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
                    '$directionLabel: ${data.counterpartyAddr}',
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

Color _glacierFill(AppColorsV3 colors) => colors.semanticGlacier.useOpacity(0.08);

Color _glacierStroke(AppColorsV3 colors) => colors.semanticGlacier.useOpacity(0.15);

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

/// Calendar days from [from] to [to], comparing date components only. Normalizing
/// through UTC keeps daylight-saving days, which elapse in 23 or 25 hours, one day apart.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String dateGroupLabel(DateTime date, AppLocalizations l10n, String localeName, {DateTime? now}) {
  // Indexer timestamps are UTC; group by the day the user saw, not the UTC day.
  final diff = calendarDaysBetween(date.toLocal(), (now ?? DateTime.now()).toLocal());
  if (diff == 0) return l10n.activityDateToday;
  if (diff == 1) return l10n.activityDateYesterday;
  return DatetimeFormattingService.formatDateGroupLabel(date, localeName);
}
