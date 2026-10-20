import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/tx_presentation.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/amount_text.dart';
import 'package:quantus_desktop_wallet/ui/components/explorer_link.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TransactionRow extends ConsumerWidget {
  final TxPresentation tx;
  final VoidCallback onTap;

  const TransactionRow({super.key, required this.tx, required this.onTap});

  Future<void> _contextMenu(BuildContext context, WidgetRef ref, Offset at) async {
    final l10n = ref.read(l10nProvider);
    final hash = tx.event.extrinsicHash;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        PopupMenuItem(value: 'address', child: Text(l10n.accountCopyAddress)),
        if (hash != null) PopupMenuItem(value: 'hash', child: Text(l10n.accountCopyHash)),
        if (hash != null) PopupMenuItem(value: 'explorer', child: Text(l10n.accountOpenExplorer)),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'address':
        await Clipboard.setData(ClipboardData(text: tx.counterparty));
        if (context.mounted) await context.showCopyToaster(message: l10n.commonCopied);
      case 'hash':
        await Clipboard.setData(ClipboardData(text: hash!));
        if (context.mounted) await context.showCopyToaster(message: l10n.commonCopied);
      case 'explorer':
        await openExplorerTransaction(hash!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    final amountColor = tx.incoming ? colors.semanticSage : colors.textContent;
    final sign = tx.incoming ? '+' : '−';
    final icon = switch (tx.event) {
      MinerRewardEvent() => Icons.hardware_rounded,
      _ => tx.incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
    };
    return GestureDetector(
      onSecondaryTapDown: (details) => _contextMenu(context, ref, details.globalPosition),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radiusV3.smBorder,
          hoverColor: colors.bgSurface2,
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderEmphasis),
                  ),
                  child: Icon(icon, size: 16, color: tx.pending ? colors.textMuted : amountColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.label, style: text.body.copyWith(color: colors.textContent)),
                      Tooltip(
                        message: tx.counterparty,
                        waitDuration: const Duration(milliseconds: 600),
                        child: Text(
                          AddressFormattingService.formatAddress(tx.counterparty),
                          style: text.dataAddress.copyWith(color: colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      '$sign${formatter.formatBalance(tx.amount, addSymbol: true)}',
                      style: text.amountRow.copyWith(color: tx.pending ? colors.textMuted : amountColor),
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      tx.pending
                          ? ref.watch(l10nProvider).accountPending
                          : DatetimeFormattingService.formatTxDateTime(tx.event.timestamp),
                      style: text.caption.copyWith(color: colors.textMuted2),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
