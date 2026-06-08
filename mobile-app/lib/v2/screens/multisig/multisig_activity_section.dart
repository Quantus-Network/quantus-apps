import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/controllers/multisig_open_proposals_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/controllers/multisig_past_proposals_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/multisig_activity_merge.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_activity_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/open_proposals_view.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/past_proposals_view.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

const _kHomeSectionItemLimit = 5;

/// Home section for a multisig account: open proposals, past proposals, and
/// chain activity as separate subsections, each with its own View All link.
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
    final pastPagination = ref.watch(multisigPastProposalsPaginationProvider(msig));
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
        OpenProposalsView.preview(
          msig: msig,
          pagination: openPagination,
          pending: pending,
          itemLimit: _kHomeSectionItemLimit,
        ),
        const SizedBox(height: 32),
        _sectionHeader(
          context,
          l10n,
          colors,
          text,
          title: l10n.multisigPastProposals,
          initialTab: MultisigActivityTab.pastProposals,
        ),
        const SizedBox(height: 16),
        PastProposalsView.preview(
          msig: msig,
          pagination: pastPagination,
          itemLimit: _kHomeSectionItemLimit,
        ),
        const SizedBox(height: 32),
        _activity(context, ref, l10n, colors, text),
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

  Widget _activity(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
  ) {
    final formatTxAmount = ref.watch(txAmountDisplayProvider);

    if (txAsync.isLoading) {
      return Column(
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
      );
    }

    if (txAsync.hasError) {
      return Column(
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
          const SizedBox(height: 12),
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
      );
    }

    final transfers = multisigActivityTransfers(
      txService: ref.read(transactionServiceProvider),
      data: txAsync.requireValue,
      multisigAccountId: msig.accountId,
    );
    final recent = transfers.take(_kHomeSectionItemLimit).toList();

    return Column(
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
              onTap: () => showTransactionDetailSheet(context, tx, msig.accountId),
            );
          }),
      ],
    );
  }
}
