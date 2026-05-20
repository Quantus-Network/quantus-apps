import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/screens/activity/activity_screen.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ActivitySection extends ConsumerStatefulWidget {
  final AsyncValue<CombinedTransactionsList> txAsync;
  final BaseAccount activeAccount;
  final Future<void> Function()? onRetry;

  const ActivitySection({super.key, required this.txAsync, required this.activeAccount, this.onRetry});

  @override
  ConsumerState<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends ConsumerState<ActivitySection> {
  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final formatTxAmount = ref.watch(txAmountDisplayProvider);
    final colors = context.colors;
    final text = context.themeText;

    return widget.txAsync.when(
      data: (data) {
        final txService = ref.read(transactionServiceProvider);
        final all = txService.combineAndDeduplicateTransactions(
          pendingCancellationIds: data.pendingCancellationIds,
          pendingTransactions: data.pendingTransactions,
          scheduledReversibleTransfers: data.scheduledReversibleTransfers,
          otherTransfers: data.otherTransfers,
        );
        final recentTransactions = all.take(5).toList();

        if (all.isEmpty) {
          return Column(
            children: [
              const SizedBox(height: 40),
              _header(colors, text, context, l10n),
              _emptyState(text, colors, l10n),
            ],
          );
        }

        return Column(
          children: [
            const SizedBox(height: 40),
            _header(colors, text, context, l10n),
            const SizedBox(height: 28),

            ...recentTransactions.mapIndexed((index, tx) {
              final data = TxItemData.from(tx, widget.activeAccount.accountId, colors, l10n);
              final isLastItem = index == recentTransactions.length - 1;

              return buildTxItem(
                tx,
                data,
                colors,
                text,
                l10n,
                formattedAmount: formatTxAmount(data.amount, isSend: data.isSend).primaryAmount,
                isLastItem: isLastItem,
                onTap: () {
                  showTransactionDetailSheet(context, tx, widget.activeAccount.accountId);
                },
              );
            }),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(colors, text, context, l10n),
            const SizedBox(height: 24),
            for (var i = 0; i < 3; i++) ...[
              const TxItemSkeleton(),
              if (i < 2) Divider(color: colors.txItemSeparator, height: 24),
            ],
          ],
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(l10n.homeActivityErrorLoading, style: text.detail?.copyWith(color: colors.textError)),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.invalidate(activeAccountTransactionsProvider);
                widget.onRetry?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  l10n.homeActivityRetry,
                  style: text.smallParagraph?.copyWith(color: colors.textPrimary, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppTextTheme text, AppColorsV2 colors, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            l10n.homeActivityEmptyTitle,
            style: text.mediumTitle?.copyWith(color: colors.textMuted, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              l10n.homeActivityEmptyMessage,
              textAlign: TextAlign.center,
              style: text.smallParagraph?.copyWith(color: colors.txItemIconDefault),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppColorsV2 colors, AppTextTheme text, BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.homeActivityTitle, style: text.smallTitle),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen())),
          child: Text(
            l10n.homeActivityViewAll,
            style: text.smallTitle?.copyWith(
              color: colors.textMuted,
              decoration: TextDecoration.underline,
              decorationColor: colors.textMuted,
              decorationStyle: TextDecorationStyle.dotted,
              decorationThickness: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
