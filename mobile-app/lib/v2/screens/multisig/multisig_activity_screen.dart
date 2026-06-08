import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/open_proposal_entry.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/controllers/multisig_open_proposals_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/multisig_activity_merge.dart';
import 'package:resonance_network_wallet/services/multisig_open_proposals_merge.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/segmented_controls.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/activity/date_grouped_refreshable_list.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/open_proposal_entry_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

enum MultisigActivityTab { openProposals, activity }

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
  late final ScrollController _activityScrollController;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _openScrollController = ScrollController()..addListener(_onOpenScroll);
    _activityScrollController = ScrollController()..addListener(_onActivityScroll);
  }

  @override
  void dispose() {
    _openScrollController.removeListener(_onOpenScroll);
    _activityScrollController.removeListener(_onActivityScroll);
    _openScrollController.dispose();
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

  Future<void> _refreshActivity() async {
    ref.invalidate(multisigPastProposalsProvider(widget.msig));
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
              SegmentedControlItem(label: l10n.homeActivityTitle, value: MultisigActivityTab.activity),
            ],
            selectedValue: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _selectedTab == MultisigActivityTab.openProposals
                ? _OpenProposalsTab(msig: widget.msig, scrollController: _openScrollController, onRefresh: _refreshOpen)
                : _ActivityTab(
                    msig: widget.msig,
                    scrollController: _activityScrollController,
                    onRefresh: _refreshActivity,
                  ),
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
    final l10n = ref.watch(l10nProvider);
    final appLocale = ref.watch(selectedAppLocaleProvider);
    final colors = context.colors;
    final text = context.themeText;
    final pagination = ref.watch(multisigOpenProposalsPaginationProvider(msig));
    final pending = pendingProposalsForMultisig(ref.watch(pendingMultisigProposalsProvider), msig.accountId);

    if (pagination.isLoading && !pagination.hasLoadedData && pending.isEmpty) {
      return const Center(child: Loader());
    }

    if (pagination.error != null && !pagination.hasLoadedData && pending.isEmpty) {
      return Center(
        child: Text(
          l10n.multisigLoadFailed(pagination.error.toString()),
          style: text.detail?.copyWith(color: colors.textError),
        ),
      );
    }

    final merged = mergeOpenProposals(pending: pending, indexed: pagination.proposals);
    final grouped = groupOpenProposalsByDate(merged, l10n, appLocale.numberFormatLocale);

    return DateGroupedRefreshableList<OpenProposalEntry>(
      scrollController: scrollController,
      onRefresh: onRefresh,
      groups: grouped,
      showLoadMoreFooter: pagination.isLoading && pagination.hasMore,
      emptyMessage: merged.isEmpty ? l10n.multisigNoOpenProposals : null,
      itemTopSpacing: 12,
      itemBuilder: (context, entry, {required isLastInGroup}) {
        return OpenProposalEntryRow(msig: msig, entry: entry);
      },
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
    final pastProposalsAsync = ref.watch(multisigPastProposalsProvider(msig));
    final pagination = ref.watch(activeAccountPaginationProvider(TransactionFilter.all));

    return txAsync.when(
      loading: () => const Center(child: Loader()),
      error: (e, _) => Center(
        child: Text(l10n.activityError(e.toString()), style: text.detail?.copyWith(color: colors.textError)),
      ),
      data: (data) {
        final pastProposals = pastProposalsAsync.value ?? const <MultisigProposal>[];
        final merged = mergeMultisigActivity(
          txService: ref.read(transactionServiceProvider),
          data: data,
          pastProposals: pastProposals,
          multisigAccountId: msig.accountId,
        );
        final grouped = groupTransactionsByDate(merged, l10n, appLocale.numberFormatLocale);

        return DateGroupedRefreshableList<TransactionEvent>(
          scrollController: scrollController,
          onRefresh: onRefresh,
          groups: grouped,
          showLoadMoreFooter: pagination != null && pagination.isLoading && pagination.hasMore,
          emptyMessage: merged.isEmpty ? l10n.activityEmpty : null,
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
              onTap: () => _onActivityTap(context, tx),
            );
          },
        );
      },
    );
  }

  void _onActivityTap(BuildContext context, TransactionEvent tx) {
    if (tx is MultisigProposalEvent) {
      showMultisigProposalDetailSheet(context, msig: msig, proposal: tx.proposal);
    } else {
      showTransactionDetailSheet(context, tx, msig.accountId);
    }
  }
}
