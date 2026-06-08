import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/multisig_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposals_section_view.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/proposal_row.dart';

/// Displays past multisig proposals in preview (home) or paginated list mode.
class PastProposalsView extends ConsumerWidget {
  const PastProposalsView.preview({
    super.key,
    required this.msig,
    required this.pagination,
    required this.itemLimit,
  }) : scrollController = null,
       onRefresh = null;

  const PastProposalsView.paginated({
    super.key,
    required this.msig,
    required this.pagination,
    required this.scrollController,
    required this.onRefresh,
  }) : itemLimit = null;

  final MultisigAccount msig;
  final MultisigProposalsPaginationState pagination;
  final int? itemLimit;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final proposals = pagination.proposals;

    Widget buildRow(BuildContext context, MultisigProposal proposal, {required bool isLastInGroup}) {
      return ProposalRow(
        proposal: proposal,
        myAccountId: msig.myMemberAccountId,
        onTap: () => showMultisigProposalDetailSheet(context, msig: msig, proposal: proposal),
      );
    }

    if (scrollController != null) {
      return MultisigProposalsSectionView.paginated(
        pagination: pagination,
        items: proposals,
        emptyMessage: l10n.multisigNoPastProposals,
        itemBuilder: buildRow,
        groupByDate: groupPastProposalsByDate,
        scrollController: scrollController!,
        onRefresh: onRefresh!,
      );
    }

    return MultisigProposalsSectionView.preview(
      pagination: pagination,
      items: proposals,
      emptyMessage: l10n.multisigNoPastProposals,
      itemBuilder: buildRow,
      itemLimit: itemLimit!,
    );
  }
}
