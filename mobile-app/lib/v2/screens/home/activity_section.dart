import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/screens/activity/activity_screen.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ActivitySection extends ConsumerWidget {
  final AsyncValue<CombinedTransactionsList> txAsync;
  final BaseAccount activeAccount;
  final Future<void> Function()? onRetry;

  const ActivitySection({super.key, required this.txAsync, required this.activeAccount, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBalanceHidden = ref.watch(isBalanceHiddenProvider);
    final colors = context.colors;
    final text = context.themeText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: txAsync.when(
        data: (data) {
          final txService = ref.read(transactionServiceProvider);
          final all = txService.combineAndDeduplicateTransactions(
            pendingCancellationIds: data.pendingCancellationIds,
            pendingTransactions: data.pendingTransactions,
            reversibleTransfers: data.reversibleTransfers,
            otherTransfers: data.otherTransfers,
          );
          final recentTransactions = all.take(5).toList();

          if (all.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 40),
                _header(colors, text, context),
                const SizedBox(height: 48),
                Icon(Icons.receipt_long_outlined, size: 48, color: colors.textTertiary),
                const SizedBox(height: 16),
                Text('No transactions yet', style: text.paragraph?.copyWith(color: colors.textSecondary)),
                const SizedBox(height: 8),
                Text('Your activity will appear here', style: text.detail?.copyWith(color: colors.textTertiary)),
              ],
            );
          }

          return Column(
            children: [
              const SizedBox(height: 40),
              _header(colors, text, context),
              const SizedBox(height: 24),

              ...recentTransactions.mapIndexed((index, tx) {
                final data = TxItemData.from(tx, activeAccount.accountId);
                final isLastItem = index == recentTransactions.length - 1;

                return buildTxItem(
                  tx,
                  data,
                  colors,
                  text,
                  isBalanceHidden: isBalanceHidden,
                  isLastItem: isLastItem,
                  onTap: () {
                    showTransactionDetailSheet(context, tx, activeAccount.accountId);
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
              _header(colors, text, context),
              const SizedBox(height: 24),
              for (var i = 0; i < 3; i++) ...[
                const Skeleton(width: double.infinity, height: 32),
                if (i < 2) Divider(color: colors.txItemSeparator, height: 24),
              ],
            ],
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              Text('Error loading transactions', style: text.detail?.copyWith(color: colors.textError)),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.invalidate(activeAccountTransactionsProvider);
                  onRetry?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'Retry',
                    style: text.smallParagraph?.copyWith(
                      color: colors.textPrimary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColorsV2 colors, AppTextTheme text, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Activity',
          style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen())),
          child: Text(
            'View All',
            style: text.paragraph?.copyWith(
              color: Colors.transparent,
              shadows: [
                Shadow(color: colors.textSecondary, offset: const Offset(0, -2)),
              ], // Shadow trick to create gap between text and underline
              decoration: TextDecoration.underline,
              decorationColor: colors.textSecondary,
              decorationStyle: TextDecorationStyle.solid,
              decorationThickness: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
