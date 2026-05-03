import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

void showTransactionDetailSheet(BuildContext context, TransactionEvent tx, String activeAccountId) {
  BottomSheetContainer.show(
    context,
    builder: (_) => _TransactionDetailSheet(tx: tx, activeAccountId: activeAccountId),
  );
}

class _TransactionDetailSheet extends StatelessWidget {
  final TransactionEvent tx;
  final String activeAccountId;

  const _TransactionDetailSheet({required this.tx, required this.activeAccountId});

  bool get _isSend => tx.from == activeAccountId;
  bool get _isPending => tx is PendingTransactionEvent;

  String get _title {
    if (_isPending) return 'Sending';
    if (tx.isReversibleScheduled) return _isSend ? 'Scheduled' : 'Receiving';
    return _isSend ? 'Sent' : 'Received';
  }

  String get _statusLabel {
    if (_isPending) return 'In Process';
    if (tx.isReversibleScheduled) return 'Scheduled';
    return 'Completed';
  }

  Color _statusColor(AppColorsV2 colors) {
    if (_isPending || tx.isReversibleScheduled) return colors.checksum;
    return colors.success;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return BottomSheetContainer(
      title: _title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _AmountSection(tx: tx, isSend: _isSend, colors: colors),
          const SizedBox(height: 20),
          _DetailRow(label: 'STATUS', value: _statusLabel, valueColor: _statusColor(colors), colors: colors),
          const SizedBox(height: 8),
          DottedBorder(
            dashLength: 3,
            gapLength: 8,
            color: colors.borderButton.useOpacity(0.5),
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 8),
          _DetailsSection(tx: tx, isSend: _isSend, colors: colors),
          const SizedBox(height: 24),
          Center(
            child: _ExplorerLink(tx: tx, colors: colors, text: text),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AmountSection extends ConsumerWidget {
  final TransactionEvent tx;
  final bool isSend;
  final AppColorsV2 colors;

  const _AmountSection({required this.tx, required this.isSend, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = ref.watch(txAmountDisplayProvider)(
      tx.amount,
      isSend: isSend,
      withQuanSymbol: false,
      customHiddenText: '-----',
    );

    return AmountDisplayWithConversion(amountDisplay: amount, colorizeAmount: !isSend);
  }
}

class _DetailsSection extends ConsumerWidget {
  final TransactionEvent tx;
  final bool isSend;
  final AppColorsV2 colors;

  const _DetailsSection({required this.tx, required this.isSend, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattingService = ref.watch(numberFormattingServiceProvider);

    final counterparty = isSend ? tx.to : tx.from;
    final address = AddressFormattingService.formatAddress(counterparty, prefix: 7, ellipses: '.......', postFix: 6);
    final dateTime = DatetimeFormattingService.formatTxDateTime(tx.timestamp);

    BigInt? fee;
    if (tx is TransferEvent) fee = (tx as TransferEvent).fee;
    if (tx is PendingTransactionEvent) fee = (tx as PendingTransactionEvent).fee;
    final feeStr = (fee != null && fee != BigInt.zero)
        ? '$formattingService).formatBalance(fee, maxDecimals: AppConstants.decimals) ${AppConstants.tokenSymbol}'
        : null;

    final txHash = tx.extrinsicHash != null
        ? AddressFormattingService.formatAddress(tx.extrinsicHash!, prefix: 6, ellipses: '...', postFix: 4)
        : null;

    return Column(
      children: [
        _DetailRow(label: isSend ? 'TO' : 'FROM', value: address, colors: colors),
        _DetailRow(label: 'DATE', value: dateTime, colors: colors),
        if (feeStr != null) _DetailRow(label: 'NETWORK FEE', value: feeStr, colors: colors),
        if (txHash != null) _DetailRow(label: 'TX HASH', value: txHash, colors: colors),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final AppColorsV2 colors;

  const _DetailRow({required this.label, required this.value, required this.colors, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final text = context.themeText;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.transactionDetailRowLabel?.copyWith(color: colors.textTertiary)),
          Text(
            value,
            style: text.transactionDetailRowValue?.copyWith(color: valueColor ?? Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _ExplorerLink extends StatelessWidget {
  final TransactionEvent tx;
  final AppColorsV2 colors;
  final AppTextTheme text;

  const _ExplorerLink({required this.tx, required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    final isPending = tx is PendingTransactionEvent;
    final color = isPending ? colors.accentOrange.withValues(alpha: 0.3) : colors.accentOrange;

    return GestureDetector(
      onTap: isPending ? null : () => _openExplorer(),
      child: Container(
        padding: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: color, width: 1)),
        ),
        child: Text(
          'View in Explorer ↗',
          style: text.smallParagraph?.copyWith(color: color, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }

  void _openExplorer() {
    final isMinerReward = tx.isMinerReward;
    String transactionType;
    if (isMinerReward) {
      transactionType = 'miner-rewards';
    } else if (tx.isReversibleScheduled) {
      transactionType = 'scheduled-reversible-transactions';
    } else if (tx.isReversibleExecuted) {
      transactionType = 'executed-reversible-transactions';
    } else if (tx.isReversibleCancelled) {
      transactionType = 'cancelled-reversible-transactions';
    } else {
      transactionType = 'immediate-transactions';
    }

    String? path;
    if (tx.extrinsicHash != null) {
      path = '$transactionType/${tx.extrinsicHash}';
    } else if (isMinerReward && tx.blockHash != null) {
      path = '$transactionType/${tx.blockHash}';
    }

    if (path != null) launchUrl(Uri.parse('${AppConstants.explorerEndpoint}/$path'));
  }
}
