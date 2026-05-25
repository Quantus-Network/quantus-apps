import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

void showTransactionDetailSheet(BuildContext context, TransactionEvent tx, String activeAccountId) {
  if (context.peekTopRouteName == transactionDetailSheetRouteSettings.name) Navigator.pop(context);

  BottomSheetContainer.show(
    context,
    builder: (_) => _TransactionDetailSheet(tx: tx, activeAccountId: activeAccountId),
    routeSettings: transactionDetailSheetRouteSettings,
  );
}

class _TransactionDetailSheet extends ConsumerWidget {
  final TransactionEvent tx;
  final String activeAccountId;

  const _TransactionDetailSheet({required this.tx, required this.activeAccountId});

  bool get _isSend => tx.from == activeAccountId;
  bool get _isPending => tx is PendingTransactionEvent;

  String _title(AppLocalizations l10n) {
    if (_isPending) return l10n.activityDetailTitleSending;
    if (tx.isReversibleScheduled) {
      return _isSend ? l10n.activityDetailTitleScheduled : l10n.activityDetailTitleReceiving;
    }
    return _isSend ? l10n.activityDetailTitleSent : l10n.activityDetailTitleReceived;
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_isPending) return l10n.activityDetailStatusInProcess;
    if (tx.isReversibleScheduled) return l10n.activityDetailStatusScheduled;
    return l10n.activityDetailStatusCompleted;
  }

  Color _statusColor(AppColorsV2 colors) {
    if (_isPending || tx.isReversibleScheduled) return colors.checksum;
    return colors.success;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    return BottomSheetContainer(
      title: _title(l10n),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _AmountSection(tx: tx, isSend: _isSend, colors: colors),
          const SizedBox(height: 20),
          _DetailRow(
            label: l10n.activityDetailStatus,
            value: _statusLabel(l10n),
            valueColor: _statusColor(colors),
            colors: colors,
          ),
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
    final l10n = ref.watch(l10nProvider);
    final formattingService = ref.watch(numberFormattingServiceProvider);

    final counterparty = isSend ? tx.to : tx.from;
    final address = AddressFormattingService.formatAddress(counterparty, prefix: 7, ellipses: '.......', postFix: 6);
    final dateTime = DatetimeFormattingService.formatTxDateTime(tx.timestamp);

    BigInt? fee;
    if (tx is TransferEvent) fee = (tx as TransferEvent).fee;
    if (tx is PendingTransactionEvent) fee = (tx as PendingTransactionEvent).fee;
    final feeStr = (fee != null && fee != BigInt.zero)
        ? l10n.commonAmountBalance(
            formattingService.formatBalance(fee, maxDecimals: AppConstants.decimals),
            AppConstants.tokenSymbol,
          )
        : null;

    final txHash = tx.extrinsicHash != null
        ? AddressFormattingService.formatAddress(tx.extrinsicHash!, prefix: 6, ellipses: '...', postFix: 4)
        : null;

    return Column(
      children: [
        _DetailRow(label: isSend ? l10n.activityDetailTo : l10n.activityDetailFrom, value: address, colors: colors),
        _DetailRow(label: l10n.activityDetailDate, value: dateTime, colors: colors),
        if (feeStr != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: feeStr, colors: colors),
        if (txHash != null) _DetailRow(label: l10n.activityDetailTxHash, value: txHash, colors: colors),
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

class _ExplorerLink extends ConsumerWidget {
  final TransactionEvent tx;
  final AppColorsV2 colors;
  final AppTextTheme text;

  const _ExplorerLink({required this.tx, required this.colors, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
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
          l10n.activityDetailViewExplorer,
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

    if (path != null) openUrl('${AppConstants.explorerEndpoint}/$path');
  }
}
