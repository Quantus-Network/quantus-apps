import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/activity/date_grouped_refreshable_list.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
                scheduledReversibleTransfers: data.scheduledReversibleTransfers,
                otherTransfers: data.otherTransfers,
              );
              final grouped = groupTransactionsByDate(all, l10n, appLocale.numberFormatLocale);
              final showLoadMoreFooter = pagination != null && pagination.isLoading && pagination.hasMore;

              return DateGroupedRefreshableList<TransactionEvent>(
                scrollController: _scrollController,
                onRefresh: _refresh,
                groups: grouped,
                showLoadMoreFooter: showLoadMoreFooter,
                emptyMessage: all.isEmpty ? l10n.activityEmpty : null,
                itemBuilder: (context, tx, {required isLastInGroup}) {
                  final itemData = TxItemData.from(tx, active.account.accountId, colors, l10n);
                  return buildTxItem(
                    tx,
                    itemData,
                    colors,
                    text,
                    l10n,
                    formattedAmount: itemData.hideAmount
                        ? '—'
                        : formatTxAmount(itemData.amount, isSend: itemData.isSend).primaryAmount,
                    isLastItem: isLastInGroup,
                    onTap: () {
                      showTransactionDetailSheet(context, tx, active.account.accountId);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
