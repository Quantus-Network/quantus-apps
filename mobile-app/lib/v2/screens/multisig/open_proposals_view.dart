import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/multisig_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/models/open_proposal_entry.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/multisig_open_proposals_merge.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposals_section_view.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/open_proposal_entry_row.dart';

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
  final MultisigProposalsPaginationState pagination;
  final List<PendingMultisigProposalEvent> pending;
  final int? itemLimit;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final merged = mergeOpenProposals(pending: pending, indexed: pagination.proposals);

    Widget buildRow(BuildContext context, OpenProposalEntry entry, {required bool isLastInGroup}) {
      return OpenProposalEntryRow(msig: msig, entry: entry);
    }

    if (scrollController != null) {
      return MultisigProposalsSectionView.paginated(
        pagination: pagination,
        items: merged,
        emptyMessage: l10n.multisigNoOpenProposals,
        bufferedItemCount: pending.length,
        itemBuilder: buildRow,
        groupByDate: groupOpenProposalsByDate,
        scrollController: scrollController!,
        onRefresh: onRefresh!,
      );
    }

    return MultisigProposalsSectionView.preview(
      pagination: pagination,
      items: merged,
      emptyMessage: l10n.multisigNoOpenProposals,
      bufferedItemCount: pending.length,
      itemBuilder: buildRow,
      itemLimit: itemLimit!,
    );
  }
}
