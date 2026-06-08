import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/models/multisig_open_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/providers/controllers/multisig_open_proposals_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/multisig_activity_merge.dart';
import 'package:resonance_network_wallet/services/multisig_open_proposals_merge.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_activity_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/open_proposal_entry_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

const _kHomeSectionItemLimit = 5;

/// Home section for a multisig account: open proposals pinned on top, followed
/// by a unified activity feed (past proposals + transfers) below.
class MultisigActivitySection extends ConsumerWidget {
  final MultisigAccount msig;
  final AsyncValue<CombinedTransactionsList> txAsync;
  final Future<void> Function()? onRetry;

  const MultisigActivitySection({super.key, required this.msig, required this.txAsync, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    final openPagination = ref.watch(multisigOpenProposalsPaginationProvider(msig));
    final pastProposalsAsync = ref.watch(multisigPastProposalsProvider(msig));
    final pending = pendingProposalsForMultisig(ref.watch(pendingMultisigProposalsProvider), msig.accountId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _sectionHeader(
          context,
          l10n,
          colors,
          text,
          title: l10n.multisigOpenProposals,
          initialTab: MultisigActivityTab.openProposals,
        ),
        const SizedBox(height: 16),
        _openProposals(context, l10n, colors, text, openPagination, pending),
        const SizedBox(height: 8),
        _activity(context, ref, l10n, colors, text, pastProposalsAsync),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text, {
    required String title,
    required MultisigActivityTab initialTab,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MultisigActivityScreen(msig: msig, initialTab: initialTab),
            ),
          ),
          child: Text(
            l10n.homeActivityViewAll,
            style: text.smallTitle?.copyWith(
              color: colors.textMuted,
              decoration: TextDecoration.underline,
              decorationColor: colors.textMuted,
              decorationStyle: TextDecorationStyle.dotted,
              decorationThickness: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _openProposals(
    BuildContext context,
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    MultisigOpenProposalsPaginationState pagination,
    List<PendingMultisigProposalEvent> pending,
  ) {
    if (pagination.isLoading && !pagination.hasLoadedData && pending.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Loader()),
      );
    }
    if (pagination.error != null && !pagination.hasLoadedData && pending.isEmpty) {
      return Text(
        l10n.multisigLoadFailed(pagination.error.toString()),
        style: text.detail?.copyWith(color: colors.textError),
      );
    }

    final merged = mergeOpenProposals(pending: pending, indexed: pagination.proposals);
    if (merged.isEmpty) {
      return Text(l10n.multisigNoOpenProposals, style: text.smallParagraph?.copyWith(color: colors.textTertiary));
    }

    final visible = merged.take(_kHomeSectionItemLimit).toList();

    return Column(
      children: visible.mapIndexed(
        (i, entry) => Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: OpenProposalEntryRow(msig: msig, entry: entry),
        ),
      ).toList(),
    );
  }

  Widget _activity(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    AsyncValue<List<MultisigProposal>> pastProposalsAsync,
  ) {
    final formatTxAmount = ref.watch(txAmountDisplayProvider);

    return txAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              context,
              l10n,
              colors,
              text,
              title: l10n.homeActivityTitle,
              initialTab: MultisigActivityTab.activity,
            ),
            const SizedBox(height: 24),
            const Center(child: Loader()),
          ],
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(l10n.homeActivityErrorLoading, style: text.detail?.copyWith(color: colors.textError)),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onRetry?.call(),
              child: Text(
                l10n.homeActivityRetry,
                style: text.smallParagraph?.copyWith(color: colors.textPrimary, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
      data: (data) {
        final merged = mergeMultisigActivity(
          txService: ref.read(transactionServiceProvider),
          data: data,
          pastProposals: pastProposalsAsync.value ?? const [],
          multisigAccountId: msig.accountId,
        );
        final recent = merged.take(_kHomeSectionItemLimit).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            _sectionHeader(
              context,
              l10n,
              colors,
              text,
              title: l10n.homeActivityTitle,
              initialTab: MultisigActivityTab.activity,
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.homeActivityEmptyTitle,
                  textAlign: TextAlign.center,
                  style: text.smallParagraph?.copyWith(color: colors.textMuted),
                ),
              )
            else
              ...recent.mapIndexed((index, tx) {
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
                  isLastItem: index == recent.length - 1,
                  onTap: () => _onTap(context, tx),
                );
              }),
          ],
        );
      },
    );
  }

  void _onTap(BuildContext context, TransactionEvent tx) {
    if (tx is MultisigProposalEvent) {
      showMultisigProposalDetailSheet(context, msig: msig, proposal: tx.proposal);
    } else {
      showTransactionDetailSheet(context, tx, msig.accountId);
    }
  }
}
