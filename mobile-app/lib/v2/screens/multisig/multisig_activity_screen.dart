import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/controllers/multisig_proposals_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/multisig_activity_merge.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/segmented_controls.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/activity/date_grouped_refreshable_list.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/open_proposals_view.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/past_proposals_view.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

enum MultisigActivityTab { openProposals, pastProposals, activity }

class MultisigActivityScreen extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final MultisigActivityTab initialTab;

  const MultisigActivityScreen({super.key, required this.msig, this.initialTab = MultisigActivityTab.activity});

  @override
  ConsumerState<MultisigActivityScreen> createState() => _MultisigActivityScreenState();
}

class _MultisigActivityScreenState extends ConsumerState<MultisigActivityScreen> {
  static const _loadMoreThreshold = 200.0;
  static const _filterOption = TransactionFilter.all;

  late MultisigActivityTab _selectedTab;
  late final ScrollController _openScrollController;
  late final ScrollController _pastScrollController;
  late final ScrollController _activityScrollController;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _openScrollController = ScrollController()..addListener(_onOpenScroll);
    _pastScrollController = ScrollController()..addListener(_onPastScroll);
    _activityScrollController = ScrollController()..addListener(_onActivityScroll);
  }

  @override
  void dispose() {
    _openScrollController.removeListener(_onOpenScroll);
    _pastScrollController.removeListener(_onPastScroll);
    _activityScrollController.removeListener(_onActivityScroll);
    _openScrollController.dispose();
    _pastScrollController.dispose();
    _activityScrollController.dispose();
    super.dispose();
  }

  void _onOpenScroll() {
    if (!_openScrollController.hasClients) return;
    final pos = _openScrollController.position;
    if (pos.maxScrollExtent <= 0 || pos.pixels < pos.maxScrollExtent - _loadMoreThreshold) return;

    final pagination = ref.read(multisigOpenProposalsPaginationProvider(widget.msig));
    if (pagination.isFetching || !pagination.hasMore) return;

    ref.read(multisigOpenProposalsPaginationProvider(widget.msig).notifier).fetchMore();
  }

  void _onPastScroll() {
    if (!_pastScrollController.hasClients) return;
    final pos = _pastScrollController.position;
    if (pos.maxScrollExtent <= 0 || pos.pixels < pos.maxScrollExtent - _loadMoreThreshold) return;

    final pagination = ref.read(multisigPastProposalsPaginationProvider(widget.msig));
    if (pagination.isFetching || !pagination.hasMore) return;

    ref.read(multisigPastProposalsPaginationProvider(widget.msig).notifier).fetchMore();
  }

  void _onActivityScroll() {
    if (!_activityScrollController.hasClients) return;
    final pos = _activityScrollController.position;
    if (pos.maxScrollExtent <= 0 || pos.pixels < pos.maxScrollExtent - _loadMoreThreshold) return;

    final pagination = ref.read(activeAccountPaginationProvider(_filterOption));
    if (pagination == null || pagination.isFetching || !pagination.hasMore) return;

    readActiveAccountPaginationNotifier(ref, _filterOption)?.fetchMore();
  }

  Future<void> _refreshOpen() async {
    await ref.read(multisigOpenProposalsPaginationProvider(widget.msig).notifier).silentRefresh();
  }

  Future<void> _refreshPast() async {
    await ref.read(multisigPastProposalsPaginationProvider(widget.msig).notifier).silentRefresh();
  }

  Future<void> _refreshActivity() async {
    await readActiveAccountPaginationNotifier(ref, _filterOption)?.silentRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.activityTitle),
      mainContent: Column(
        children: [
          SegmentedControls<MultisigActivityTab>(
            items: [
              SegmentedControlItem(label: l10n.multisigOpenProposals, value: MultisigActivityTab.openProposals),
              SegmentedControlItem(label: l10n.multisigPastProposals, value: MultisigActivityTab.pastProposals),
              SegmentedControlItem(label: l10n.homeActivityTitle, value: MultisigActivityTab.activity),
            ],
            selectedValue: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: switch (_selectedTab) {
              MultisigActivityTab.openProposals => _OpenProposalsTab(
                msig: widget.msig,
                scrollController: _openScrollController,
                onRefresh: _refreshOpen,
              ),
              MultisigActivityTab.pastProposals => _PastProposalsTab(
                msig: widget.msig,
                scrollController: _pastScrollController,
                onRefresh: _refreshPast,
              ),
              MultisigActivityTab.activity => _ActivityTab(
                msig: widget.msig,
                scrollController: _activityScrollController,
                onRefresh: _refreshActivity,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _OpenProposalsTab extends ConsumerWidget {
  final MultisigAccount msig;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const _OpenProposalsTab({required this.msig, required this.scrollController, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagination = ref.watch(multisigOpenProposalsPaginationProvider(msig));
    final pending = pendingProposalsForMultisig(ref.watch(pendingMultisigProposalsProvider), msig.accountId);

    return OpenProposalsView.paginated(
      msig: msig,
      pagination: pagination,
      pending: pending,
      scrollController: scrollController,
      onRefresh: onRefresh,
    );
  }
}

class _PastProposalsTab extends ConsumerWidget {
  final MultisigAccount msig;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const _PastProposalsTab({required this.msig, required this.scrollController, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagination = ref.watch(multisigPastProposalsPaginationProvider(msig));

    return PastProposalsView.paginated(
      msig: msig,
      pagination: pagination,
      scrollController: scrollController,
      onRefresh: onRefresh,
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  final MultisigAccount msig;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const _ActivityTab({required this.msig, required this.scrollController, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final appLocale = ref.watch(selectedAppLocaleProvider);
    final colors = context.colors;
    final text = context.themeText;
    final formatTxAmount = ref.watch(txAmountDisplayProvider);
    final txAsync = ref.watch(activeAccountTransactionsProvider(TransactionFilter.all));
    final pagination = ref.watch(activeAccountPaginationProvider(TransactionFilter.all));

    if (txAsync.isLoading) {
      return const Center(child: Loader());
    }
    if (txAsync.hasError) {
      return Center(
        child: Text(
          l10n.activityError(txAsync.error.toString()),
          style: text.detail?.copyWith(color: colors.textError),
        ),
      );
    }

    final data = txAsync.requireValue;
    final transfers = multisigActivityTransfers(
      txService: ref.read(transactionServiceProvider),
      data: data,
      multisigAccountId: msig.accountId,
    );
    final grouped = groupTransactionsByDate(transfers, l10n, appLocale.numberFormatLocale);

    return DateGroupedRefreshableList<TransactionEvent>(
      scrollController: scrollController,
      onRefresh: onRefresh,
      groups: grouped,
      showLoadMoreFooter: pagination != null && pagination.isLoading && pagination.hasMore,
      emptyMessage: transfers.isEmpty ? l10n.activityEmpty : null,
      itemBuilder: (context, tx, {required isLastInGroup}) {
        final itemData = TxItemData.from(tx, msig.accountId, colors, l10n);
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
          onTap: () => showTransactionDetailSheet(context, tx, msig.accountId),
        );
      },
    );
  }
}
