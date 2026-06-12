import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_executions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/proposal_list_tile.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/proposal_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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

    final openProposalsAsync = ref.watch(multisigOpenProposalsProvider(msig));
    final pastProposalsAsync = ref.watch(multisigPastProposalsProvider(msig));
    final pending = pendingProposalsForMultisig(ref.watch(pendingMultisigProposalsProvider), msig.accountId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(l10n.multisigOpenProposals, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 16),
        _openProposals(context, l10n, colors, text, openProposalsAsync, pending),
        const SizedBox(height: 8),
        _activity(context, ref, l10n, colors, text, pastProposalsAsync),
      ],
    );
  }

  Widget _openProposals(
    BuildContext context,
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    AsyncValue<List<MultisigProposal>> openProposalsAsync,
    List<PendingMultisigProposalEvent> pending,
  ) {
    if (openProposalsAsync.isLoading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Loader()),
      );
    }
    if (openProposalsAsync.hasError && pending.isEmpty) {
      return Text(
        l10n.multisigLoadFailed(openProposalsAsync.error.toString()),
        style: text.detail?.copyWith(color: colors.textError),
      );
    }

    final openProposals = [...(openProposalsAsync.value ?? const <MultisigProposal>[])]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (pending.isEmpty && openProposals.isEmpty) {
      return Text(l10n.multisigNoOpenProposals, style: text.smallParagraph?.copyWith(color: colors.textTertiary));
    }

    return Column(
      children: [
        ...pending.mapIndexed(
          (i, p) => Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: PendingProposalRow(pending: p, onTap: () => showTransactionDetailSheet(context, p, msig.accountId)),
          ),
        ),
        ...openProposals.mapIndexed(
          (i, p) => Padding(
            padding: EdgeInsets.only(top: (i == 0 && pending.isEmpty) ? 0 : 12),
            child: ProposalRow(
              proposal: p,
              myAccountId: msig.myMemberAccountId,
              onTap: () => showMultisigProposalDetailSheet(context, msig: msig, proposal: p),
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
    AsyncValue<List<MultisigProposal>> pastProposalsAsync,
  ) {
    final formatTxAmount = ref.watch(txAmountDisplayProvider);

    return txAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Loader()),
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
        final merged = _mergedActivity(ref, data, pastProposalsAsync.value ?? const []);
        final recent = merged.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(l10n.homeActivityTitle, style: text.smallTitle),
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

  /// Merges past proposals with transfers, newest first. Outgoing multisig
  /// transfers are omitted because executed proposals already represent them.
  List<TransactionEvent> _mergedActivity(
    WidgetRef ref,
    CombinedTransactionsList data,
    List<MultisigProposal> pastProposals,
  ) {
    final txService = ref.read(transactionServiceProvider);
    final transfers = txService.combineAndDeduplicateTransactions(
      pendingCancellationIds: data.pendingCancellationIds,
      pendingTransactions: data.pendingTransactions,
      pendingMultisigCreations: data.pendingMultisigCreations,
      pendingMultisigProposals: pendingProposalsExcludingMultisig(data.pendingMultisigProposals, msig.accountId),
      pendingMultisigExecutions: pendingExecutionsExcludingMultisig(data.pendingMultisigExecutions, msig.accountId),
      pendingMultisigCancellations: pendingCancellationsExcludingMultisig(
        data.pendingMultisigCancellations,
        msig.accountId,
      ),
      scheduledReversibleTransfers: data.scheduledReversibleTransfers,
      otherTransfers: data.otherTransfers,
    );

    final terminalProposals = pastProposals.map((p) => MultisigProposalEvent(proposal: p)).toList();
    final filteredTransfers = transfers.where((t) {
      return t is! TransferEvent || t.from != msig.accountId;
    });

    final merged = <TransactionEvent>[...terminalProposals, ...filteredTransfers]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  void _onTap(BuildContext context, TransactionEvent tx) {
    if (tx is MultisigProposalEvent) {
      showMultisigProposalDetailSheet(context, msig: msig, proposal: tx.proposal);
    } else {
      showTransactionDetailSheet(context, tx, msig.accountId);
    }
  }
}
