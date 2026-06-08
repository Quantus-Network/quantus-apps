import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/multisig_past_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/screens/activity/date_grouped_refreshable_list.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/proposal_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
  final MultisigPastProposalsPaginationState pagination;
  final int? itemLimit;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;

  bool get _isPaginated => scrollController != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    if (pagination.isLoading && !pagination.hasLoadedData) {
      if (_isPaginated) {
        return const Center(child: Loader());
      }
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Loader()),
      );
    }

    if (pagination.error != null && !pagination.hasLoadedData) {
      final message = Text(
        l10n.multisigLoadFailed(pagination.error.toString()),
        style: text.detail?.copyWith(color: colors.textError),
      );
      return _isPaginated ? Center(child: message) : message;
    }

    final proposals = pagination.proposals;

    if (_isPaginated) {
      final appLocale = ref.watch(selectedAppLocaleProvider);
      final grouped = groupPastProposalsByDate(proposals, l10n, appLocale.numberFormatLocale);
      return DateGroupedRefreshableList<MultisigProposal>(
        scrollController: scrollController!,
        onRefresh: onRefresh!,
        groups: grouped,
        showLoadMoreFooter: pagination.isLoading && pagination.hasMore,
        emptyMessage: proposals.isEmpty ? l10n.multisigNoPastProposals : null,
        itemTopSpacing: 12,
        itemBuilder: (context, proposal, {required isLastInGroup}) {
          return ProposalRow(
            proposal: proposal,
            myAccountId: msig.myMemberAccountId,
            onTap: () => showMultisigProposalDetailSheet(context, msig: msig, proposal: proposal),
          );
        },
      );
    }

    if (proposals.isEmpty) {
      return Text(
        l10n.multisigNoPastProposals,
        style: text.smallParagraph?.copyWith(color: colors.textTertiary),
      );
    }

    final visible = proposals.take(itemLimit!).toList();
    return Column(
      children: visible.mapIndexed(
        (i, proposal) => Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: ProposalRow(
            proposal: proposal,
            myAccountId: msig.myMemberAccountId,
            onTap: () => showMultisigProposalDetailSheet(context, msig: msig, proposal: proposal),
          ),
        ),
      ).toList(),
    );
  }
}
