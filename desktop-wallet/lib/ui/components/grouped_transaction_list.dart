import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:quantus_desktop_wallet/models/tx_presentation.dart';
import 'package:quantus_desktop_wallet/providers/history_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/transaction_detail_dialog.dart';
import 'package:quantus_desktop_wallet/ui/components/transaction_row.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Pending entries first, then history grouped by day.
class GroupedTransactionList extends ConsumerWidget {
  final AccountHistory history;
  final String accountId;
  final int? limit;
  final VoidCallback? onLoadMore;

  const GroupedTransactionList({
    super.key,
    required this.history,
    required this.accountId,
    this.limit,
    this.onLoadMore,
  });

  String _dayLabel(DateTime at, DateTime now, AppLocalizations l10n) {
    final day = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return l10n.accountToday;
    if (difference == 1) return l10n.accountYesterday;
    return DateFormat.yMMMd().format(at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final header = text.labelMonogram.copyWith(color: colors.textMuted);
    final now = DateTime.now();
    final events = limit == null ? history.events : history.events.take(limit!).toList();
    final children = <Widget>[];

    if (history.pending.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Text(l10n.accountPending.toUpperCase(), style: header),
        ),
      );
      for (final tx in history.pending) {
        final presentation = TxPresentation.of(tx, accountId: accountId, l10n: l10n);
        children.add(TransactionRow(tx: presentation, onTap: () => showTransactionDetailDialog(context, presentation)));
      }
    }
    String? currentDay;
    for (final event in events) {
      final label = _dayLabel(event.timestamp, now, l10n);
      if (label != currentDay) {
        currentDay = label;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Text(label.toUpperCase(), style: header),
          ),
        );
      }
      final presentation = TxPresentation.of(event, accountId: accountId, l10n: l10n);
      children.add(TransactionRow(tx: presentation, onTap: () => showTransactionDetailDialog(context, presentation)));
    }
    if (history.isLoading) {
      children.addAll([
        for (var i = 0; i < 5; i++)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Skeleton(height: 40)),
      ]);
    } else if (children.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.accountNoTransactions,
            style: text.body.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (history.error != null && !history.isLoading) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(l10n.accountHistoryError, style: text.caption.copyWith(color: colors.semanticEmber)),
        ),
      );
    }
    if (onLoadMore != null && history.hasMore && !history.isLoading) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: QuantusButton.simple(
            label: l10n.commonLoadMore,
            variant: ButtonVariant.staged,
            isLoading: history.isFetching,
            onTap: onLoadMore,
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
