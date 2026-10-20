import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/tx_presentation.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/copyable_text.dart';
import 'package:quantus_desktop_wallet/ui/components/explorer_link.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

Future<void> showTransactionDetailDialog(BuildContext context, TxPresentation tx) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(48),
    child: TransactionDetailDialog(tx: tx),
  ),
);

class TransactionDetailDialog extends ConsumerWidget {
  final TxPresentation tx;

  const TransactionDetailDialog({super.key, required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    final event = tx.event;
    final hash = event.extrinsicHash;
    final counterpartyPhrase = ref.watch(checksumNameProvider(tx.counterparty)).value;
    return QuantusDialogFrame(
      maxWidth: 520,
      child: SelectionArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(tx.label, style: text.titleScreen.copyWith(color: colors.textContent)),
                ),
                QuantusBadge(
                  label: tx.pending ? l10n.txDetailStatusPending : l10n.txDetailStatusConfirmed,
                  tone: tx.pending ? BadgeTone.glacier : BadgeTone.sage,
                  dot: tx.pending,
                ),
              ],
            ),
            const SizedBox(height: 16),
            DetailSummaryRow.stacked(label: l10n.txDetailAmount, value: formatter.formatExactAmount(tx.amount)),
            if (tx.fee != null)
              DetailSummaryRow.stacked(label: l10n.txDetailFee, value: formatter.formatExactAmount(tx.fee!)),
            DetailSummaryRow.stacked(
              label: tx.incoming ? l10n.txDetailFrom : l10n.txDetailTo,
              value: tx.counterparty,
              monospace: true,
              checkphrase: counterpartyPhrase,
            ),
            DetailSummaryRow.stacked(
              label: l10n.txDetailDate,
              value: DatetimeFormattingService.formatTxDateTime(event.timestamp),
            ),
            if (event.blockNumber > 0)
              DetailSummaryRow.stacked(label: l10n.txDetailBlock, value: '${event.blockNumber}'),
            if (hash != null) ...[
              const SizedBox(height: 8),
              Text(l10n.txDetailHash.toUpperCase(), style: text.labelMonogram.copyWith(color: colors.textMuted)),
              CopyableText(value: hash, copiedMessage: l10n.commonCopied),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (hash != null) ExplorerLink(extrinsicHash: hash, label: l10n.accountOpenExplorer),
                const Spacer(),
                QuantusButton.simple(
                  label: l10n.commonClose,
                  variant: ButtonVariant.staged,
                  width: 120,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
