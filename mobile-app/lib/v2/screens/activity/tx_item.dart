import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class TxItemData {
  final String label;
  final String timeLabel;
  final Color iconBg;
  final Color iconColor;
  final bool isSend;
  final String amount;
  final String counterpartyAddr;

  const TxItemData({
    required this.label,
    required this.timeLabel,
    required this.iconBg,
    required this.iconColor,
    required this.isSend,
    required this.amount,
    required this.counterpartyAddr,
  });

  factory TxItemData.from(TransactionEvent tx, String accountId) {
    final isSend = tx.from == accountId;
    final isScheduled = tx.isReversibleScheduled;
    final fmt = NumberFormattingService();

    return TxItemData(
      label: isScheduled
          ? (isSend ? 'Pending' : 'Receiving')
          : isSend
          ? 'Sent'
          : 'Received',
      timeLabel: isScheduled ? _formatDuration(tx.timeRemaining) : _timeAgo(tx.timestamp),
      iconBg: isScheduled && !isSend
          ? const Color(0x2927F027)
          : isScheduled && isSend
          ? const Color(0x29FFBC42)
          : const Color(0xFF292929),
      iconColor: isScheduled && !isSend
          ? const Color(0xFF27F027)
          : isScheduled && isSend
          ? const Color(0xFFFFBC42)
          : const Color(0x80FFFFFF),
      isSend: isSend,
      amount: '${fmt.formatBalance(tx.amount)} ${AppConstants.tokenSymbol}',
      counterpartyAddr: _shortenAddress(isSend ? tx.to : tx.from),
    );
  }
}

Widget buildTxItem(
  TransactionEvent tx,
  TxItemData data,
  AppColorsV2 colors,
  AppTextTheme text, {
  required bool isBalanceHidden,
  required bool isLastItem,
  VoidCallback? onTap,
}) {
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: data.iconBg, borderRadius: BorderRadius.circular(6)),
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
                    Text(data.label, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(data.timeLabel, style: text.detail?.copyWith(color: colors.textTertiary)),
                  ],
                ),
              ),
              if (!isBalanceHidden)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(data.amount, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${data.isSend ? "To" : "From"}: ${data.counterpartyAddr}',
                      style: text.detail?.copyWith(color: colors.textTertiary),
                    ),
                  ],
                )
              else
                Center(
                  child: Text('--------', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                ),
            ],
          ),
        ),
        if (!isLastItem) Divider(color: colors.txItemSeparator, height: 1),
      ],
    ),
  );
}

String _shortenAddress(String addr) {
  if (addr.length <= 10) return addr;
  return '${addr.substring(0, 5)}...${addr.substring(addr.length - 3)}';
}

String _formatDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final mins = d.inMinutes % 60;
  return '${days.toString().padLeft(2, '0')}d:${hours.toString().padLeft(2, '0')}h:${mins.toString().padLeft(2, '0')}m';
}

String _timeAgo(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String dateGroupLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final txDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(txDay).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
