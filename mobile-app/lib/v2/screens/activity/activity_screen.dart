import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final accountAsync = ref.watch(activeAccountProvider);
    final txAsync = ref.watch(activeAccountTransactionsProvider);
    final isBalanceHidden = ref.watch(isBalanceHiddenProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBackButton(),
                    Text('Activity', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
                    const SizedBox(width: 24), // empty filler
                    // Icon(Icons.info_outline, color: colors.textPrimary, size: 24),
                  ],
                ),
                const SizedBox(height: 48),
                Expanded(
                  child: accountAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: colors.textPrimary)),
                    error: (e, _) => Center(
                      child: Text('Error: $e', style: text.detail?.copyWith(color: colors.textError)),
                    ),
                    data: (active) {
                      if (active == null) return const Center(child: Text('No account'));
                      return txAsync.when(
                        loading: () => Center(child: CircularProgressIndicator(color: colors.textPrimary)),
                        error: (e, _) => Center(
                          child: Text('Error: $e', style: text.detail?.copyWith(color: colors.textError)),
                        ),
                        data: (data) {
                          final txService = ref.read(transactionServiceProvider);
                          final all = txService.combineAndDeduplicateTransactions(
                            pendingCancellationIds: data.pendingCancellationIds,
                            pendingTransactions: data.pendingTransactions,
                            reversibleTransfers: data.reversibleTransfers,
                            otherTransfers: data.otherTransfers,
                          );
                          if (all.isEmpty) {
                            return Center(
                              child: Text(
                                'No transactions yet',
                                style: text.paragraph?.copyWith(color: colors.textSecondary),
                              ),
                            );
                          }
                          final grouped = _groupByDate(all);
                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: grouped.length,
                            itemBuilder: (context, i) {
                              final group = grouped[i];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (i > 0) const SizedBox(height: 40),
                                  Text(
                                    group.label,
                                    style: text.paragraph?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...group.transactions.mapIndexed((index, tx) {
                                    final itemData = TxItemData.from(tx, active.account.accountId);
                                    final isLastItem = index == group.transactions.length - 1;
                                    return buildTxItem(
                                      tx,
                                      itemData,
                                      colors,
                                      text,
                                      isBalanceHidden: isBalanceHidden,
                                      isLastItem: isLastItem,
                                      onTap: () {
                                        showTransactionDetailSheet(context, tx, active.account.accountId);
                                      },
                                    );
                                  }),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<TransactionEvent> transactions) {
    final Map<String, List<TransactionEvent>> groups = {};
    final Map<String, String> labelMap = {};

    for (final tx in transactions) {
      final day = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      final key = '${day.year}-${day.month}-${day.day}';
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(tx);
      labelMap.putIfAbsent(key, () => dateGroupLabel(tx.timestamp));
    }

    return groups.entries.map((e) => _DateGroup(label: labelMap[e.key]!, transactions: e.value)).toList();
  }
}

class _DateGroup {
  final String label;
  final List<TransactionEvent> transactions;
  const _DateGroup({required this.label, required this.transactions});
}
