import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  TransactionFilter _filterOption = TransactionFilter.all;

  void _onFilterOptionChanged(TransactionFilter option) {
    if (_filterOption == option) return;
    setState(() {
      _filterOption = option;
    });
  }

  String _filterLabel(TransactionFilter filter, AppLocalizations l10n) => switch (filter) {
    TransactionFilter.all => l10n.activityFilterAll,
    TransactionFilter.send => l10n.activityFilterSend,
    TransactionFilter.receive => l10n.activityFilterReceive,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final appLocale = ref.watch(selectedAppLocaleProvider);
    final colors = context.colors;
    final text = context.themeText;
    final accountAsync = ref.watch(activeAccountProvider);
    final txAsync = ref.watch(activeAccountTransactionsProvider(_filterOption));
    final formatTxAmount = ref.watch(txAmountDisplayProvider);

    final filterButtons = TransactionFilter.values
        .map(
          (e) => _buildFilterButton(
            _filterLabel(e, l10n),
            onTap: () => _onFilterOptionChanged(e),
            isSelected: _filterOption == e,
          ),
        )
        .toList();

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.activityTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(spacing: 12, children: filterButtons),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: accountAsync.when(
              loading: () => const Center(child: Loader()),
              error: (e, _) => Center(
                child: Text(l10n.activityError(e.toString()), style: text.detail?.copyWith(color: colors.textError)),
              ),
              data: (active) {
                if (active == null) {
                  return Center(child: Text(l10n.activityNoAccount));
                }
                return txAsync.when(
                  loading: () => ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, i) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (i > 0) const SizedBox(height: 32),
                        const Skeleton(width: 100, height: 24),
                        const SizedBox(height: 12),
                        for (var j = 0; j < 3; j++) ...[
                          const TxItemSkeleton(),
                          if (j < 2) Divider(color: colors.txItemSeparator, height: 24),
                        ],
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      l10n.activityError(e.toString()),
                      style: text.detail?.copyWith(color: colors.textError),
                    ),
                  ),
                  data: (data) {
                    final txService = ref.read(transactionServiceProvider);
                    final all = txService.combineAndDeduplicateTransactions(
                      pendingCancellationIds: data.pendingCancellationIds,
                      pendingTransactions: data.pendingTransactions,
                      scheduledReversibleTransfers: data.scheduledReversibleTransfers,
                      otherTransfers: data.otherTransfers,
                    );
                    if (all.isEmpty) {
                      return Center(
                        child: Text(l10n.activityEmpty, style: text.paragraph?.copyWith(color: colors.textSecondary)),
                      );
                    }
                    final grouped = _groupByDate(all, l10n, appLocale.numberFormatLocale);

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: grouped.length,
                      itemBuilder: (context, i) {
                        final group = grouped[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (i > 0) const SizedBox(height: 32),
                            Text(group.label, style: text.receiveLabel?.copyWith(color: colors.textTertiary)),
                            ...group.transactions.mapIndexed((index, tx) {
                              final itemData = TxItemData.from(tx, active.account.accountId, colors, l10n);
                              final isLastItem = index == group.transactions.length - 1;
                              return buildTxItem(
                                tx,
                                itemData,
                                colors,
                                text,
                                l10n,
                                formattedAmount: formatTxAmount(itemData.amount, isSend: itemData.isSend).primaryAmount,
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
    );
  }

  Widget _buildFilterButton(String label, {bool isSelected = false, required VoidCallback onTap}) {
    final variant = isSelected ? ButtonVariant.primary : ButtonVariant.outline;

    return IntrinsicWidth(
      child: QuantusButton.simple(
        label: label,
        variant: variant,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        onTap: onTap,
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<TransactionEvent> transactions, AppLocalizations l10n, String localeName) {
    final Map<String, List<TransactionEvent>> groups = {};
    final Map<String, String> labelMap = {};

    for (final tx in transactions) {
      final day = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      final key = '${day.year}-${day.month}-${day.day}';
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(tx);
      labelMap.putIfAbsent(key, () => dateGroupLabel(tx.timestamp, l10n, localeName));
    }

    return groups.entries.map((e) => _DateGroup(label: labelMap[e.key]!.toUpperCase(), transactions: e.value)).toList();
  }
}

class _DateGroup {
  final String label;
  final List<TransactionEvent> transactions;
  const _DateGroup({required this.label, required this.transactions});
}
