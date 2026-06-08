import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/multisig_open_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/models/open_proposal_entry.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/multisig_open_proposals_merge.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/screens/activity/date_grouped_refreshable_list.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/open_proposal_entry_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Displays open multisig proposals in preview (home) or paginated list mode.
class OpenProposalsView extends ConsumerWidget {
  const OpenProposalsView.preview({
    super.key,
    required this.msig,
    required this.pagination,
    required this.pending,
    required this.itemLimit,
  }) : scrollController = null,
       onRefresh = null;

  const OpenProposalsView.paginated({
    super.key,
    required this.msig,
    required this.pagination,
    required this.pending,
    required this.scrollController,
    required this.onRefresh,
  }) : itemLimit = null;

  final MultisigAccount msig;
  final MultisigOpenProposalsPaginationState pagination;
  final List<PendingMultisigProposalEvent> pending;
  final int? itemLimit;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;

  bool get _isPaginated => scrollController != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    if (pagination.isLoading && !pagination.hasLoadedData && pending.isEmpty) {
      if (_isPaginated) {
        return const Center(child: Loader());
      }
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Loader()),
      );
    }

    if (pagination.error != null && !pagination.hasLoadedData && pending.isEmpty) {
      final message = Text(
        l10n.multisigLoadFailed(pagination.error.toString()),
        style: text.detail?.copyWith(color: colors.textError),
      );
      return _isPaginated ? Center(child: message) : message;
    }

    final merged = mergeOpenProposals(pending: pending, indexed: pagination.proposals);

    if (_isPaginated) {
      final appLocale = ref.watch(selectedAppLocaleProvider);
      final grouped = groupOpenProposalsByDate(merged, l10n, appLocale.numberFormatLocale);
      return DateGroupedRefreshableList<OpenProposalEntry>(
        scrollController: scrollController!,
        onRefresh: onRefresh!,
        groups: grouped,
        showLoadMoreFooter: pagination.isLoading && pagination.hasMore,
        emptyMessage: merged.isEmpty ? l10n.multisigNoOpenProposals : null,
        itemTopSpacing: 12,
        itemBuilder: (context, entry, {required isLastInGroup}) {
          return OpenProposalEntryRow(msig: msig, entry: entry);
        },
      );
    }

    if (merged.isEmpty) {
      return Text(
        l10n.multisigNoOpenProposals,
        style: text.smallParagraph?.copyWith(color: colors.textTertiary),
      );
    }

    final visible = merged.take(itemLimit!).toList();
    return Column(
      children: visible.mapIndexed(
        (i, entry) => Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: OpenProposalEntryRow(msig: msig, entry: entry),
        ),
      ).toList(),
    );
  }
}
