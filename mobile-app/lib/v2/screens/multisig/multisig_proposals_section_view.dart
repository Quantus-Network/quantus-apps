import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/multisig_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/screens/activity/date_grouped_refreshable_list.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

typedef ProposalsDateGrouper<T> =
    List<ActivityDateGroup<T>> Function(
      List<T> items,
      AppLocalizations l10n,
      String localeName,
    );

typedef ProposalsItemBuilder<T> =
    Widget Function(BuildContext context, T item, {required bool isLastInGroup});

/// Shared preview/paginated layout for multisig proposal lists.
class MultisigProposalsSectionView<T> extends ConsumerWidget {
  const MultisigProposalsSectionView.preview({
    super.key,
    required this.pagination,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
    required this.itemLimit,
    this.bufferedItemCount = 0,
  }) : scrollController = null,
       onRefresh = null,
       groupByDate = null;

  const MultisigProposalsSectionView.paginated({
    super.key,
    required this.pagination,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
    required this.groupByDate,
    required this.scrollController,
    required this.onRefresh,
    this.bufferedItemCount = 0,
  }) : itemLimit = null;

  final MultisigProposalsPaginationState pagination;
  final List<T> items;
  final String emptyMessage;
  final ProposalsItemBuilder<T> itemBuilder;
  final int bufferedItemCount;
  final int? itemLimit;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  final ProposalsDateGrouper<T>? groupByDate;

  bool get _isPaginated => scrollController != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    if (pagination.isLoading && !pagination.hasLoadedData && bufferedItemCount == 0) {
      if (_isPaginated) {
        return const Center(child: Loader());
      }
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Loader()),
      );
    }

    if (pagination.error != null && !pagination.hasLoadedData && bufferedItemCount == 0) {
      final message = Text(
        l10n.multisigLoadFailed(pagination.error.toString()),
        style: text.detail?.copyWith(color: colors.textError),
      );
      return _isPaginated ? Center(child: message) : message;
    }

    if (_isPaginated) {
      final appLocale = ref.watch(selectedAppLocaleProvider);
      final grouped = groupByDate!(items, l10n, appLocale.numberFormatLocale);
      return DateGroupedRefreshableList<T>(
        scrollController: scrollController!,
        onRefresh: onRefresh!,
        groups: grouped,
        showLoadMoreFooter: pagination.isLoading && pagination.hasMore,
        emptyMessage: items.isEmpty ? emptyMessage : null,
        itemTopSpacing: 12,
        itemBuilder: itemBuilder,
      );
    }

    if (items.isEmpty) {
      return Text(
        emptyMessage,
        style: text.smallParagraph?.copyWith(color: colors.textTertiary),
      );
    }

    final visible = items.take(itemLimit!).toList();
    return Column(
      children: visible.mapIndexed(
        (i, item) => Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: itemBuilder(context, item, isLastInGroup: i == visible.length - 1),
        ),
      ).toList(),
    );
  }
}
