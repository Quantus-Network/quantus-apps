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
  static const _loadMoreThreshold = 200.0;
  static const _filterOption = TransactionFilter.all;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0 || pos.pixels < pos.maxScrollExtent - _loadMoreThreshold) return;

    final pagination = ref.read(activeAccountPaginationProvider(_filterOption));
    if (pagination == null || pagination.isFetching || !pagination.hasMore) return;

    readActiveAccountPaginationNotifier(ref, _filterOption)?.fetchMore();
  }

  Future<void> _refresh() async {
    final pagination = ref.read(activeAccountPaginationProvider(_filterOption));
    if (pagination == null || pagination.isFetching) return;

    await readActiveAccountPaginationNotifier(ref, _filterOption)?.silentRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final appLocale = ref.watch(selectedAppLocaleProvider);
    final colors = context.colors;
    final text = context.themeText;
    final accountAsync = ref.watch(activeAccountProvider);
    final txAsync = ref.watch(activeAccountTransactionsProvider(_filterOption));
    final pagination = ref.watch(activeAccountPaginationProvider(_filterOption));
    final formatTxAmount = ref.watch(txAmountDisplayProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.activityTitle),
      mainContent: accountAsync.when(
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
              child: Text(l10n.activityError(e.toString()), style: text.detail?.copyWith(color: colors.textError)),
            ),
            data: (data) {
              final txService = ref.read(transactionServiceProvider);
              final all = txService.combineAndDeduplicateTransactions(
                pendingCancellationIds: data.pendingCancellationIds,
                pendingTransactions: data.pendingTransactions,
                pendingMultisigCreations: data.pendingMultisigCreations,
                pendingMultisigProposals: data.pendingMultisigProposals,
                pendingMultisigExecutions: data.pendingMultisigExecutions,
                pendingMultisigCancellations: data.pendingMultisigCancellations,
                scheduledReversibleTransfers: data.scheduledReversibleTransfers,
                otherTransfers: data.otherTransfers,
              );
              if (all.isEmpty) {
                return _buildRefreshableContent(
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Text(
                              l10n.activityEmpty,
                              style: text.paragraph?.copyWith(color: colors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final grouped = _groupByDate(all, l10n, appLocale.numberFormatLocale);
              final showLoadMoreFooter = pagination != null && pagination.isLoading && pagination.hasMore;

              return _buildRefreshableContent(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: grouped.length + (showLoadMoreFooter ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (showLoadMoreFooter && i == grouped.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Loader()),
                      );
                    }

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
                            formattedAmount: itemData.hideAmount
                                ? '—'
                                : formatTxAmount(itemData.amount, isSend: itemData.isSend).primaryAmount,
                            isLastItem: isLastItem,
                            onTap: () {
                              showTransactionDetailSheet(context, tx, active.account.accountId);
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRefreshableContent({required Widget child}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: context.colors.textPrimary,
      backgroundColor: context.colors.surface,
      child: child,
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
