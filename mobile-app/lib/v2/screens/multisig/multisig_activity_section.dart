import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/multisig_activity.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/services/transaction_service.dart';
import 'package:resonance_network_wallet/v2/components/proposal_list_tile.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/proposal_row.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_activity_row.dart';

/// Home section for a multisig account: open proposals pinned on top, followed
/// by a unified activity feed (past proposals + transfers) below.
class MultisigActivitySection extends ConsumerWidget {
  final MultisigAccount msig;
  final AsyncValue<CombinedTransactionsList> txAsync;
  final Future<void> Function()? onRetry;

  /// Masks the amounts in the activity feed. Passed down by the home screen,
  /// which owns the hide-balances toggle. Open proposals are never masked:
  /// they are pending decisions, not balance disclosure.
  final bool isHidden;

  const MultisigActivitySection({
    super.key,
    required this.msig,
    required this.txAsync,
    this.onRetry,
    this.isHidden = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    final openProposalsAsync = ref.watch(multisigOpenProposalsProvider(msig));
    final pastProposalsAsync = ref.watch(multisigPastProposalsProvider(msig));
    final open = openProposalsOf(
      msig,
      proposing: ref.watch(pendingMultisigProposalsProvider),
      open: openProposalsAsync.value ?? const [],
    );
    final localSignerIds = localSignerIdsOf(msig, ref.watch(accountsProvider).value ?? const <Account>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(l10n.multisigOpenProposals, style: text.headingRow.copyWith(color: colors.textContent)),
        const SizedBox(height: 16),
        _openProposals(context, l10n, openProposalsAsync, open, localSignerIds),
        const SizedBox(height: 8),
        _activity(context, ref, l10n, pastProposalsAsync),
      ],
    );
  }

  Widget _openProposals(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<MultisigProposal>> openProposalsAsync,
    ({List<PendingMultisigProposalEvent> proposing, List<MultisigProposal> open}) open,
    List<String> localSignerIds,
  ) {
    final pending = open.proposing;
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    if (openProposalsAsync.isLoading && !openProposalsAsync.hasValue) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Loader()),
      );
    }
    if (openProposalsAsync.hasError && !openProposalsAsync.hasValue && pending.isEmpty) {
      return Text(
        l10n.multisigLoadFailed(openProposalsAsync.error.toString()),
        style: text.caption.copyWith(color: colors.semanticEmber),
      );
    }

    final openProposals = open.open;
    if (pending.isEmpty && openProposals.isEmpty) {
      return Text(l10n.multisigNoOpenProposals, style: text.body.copyWith(color: colors.textMuted));
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
              localSignerIds: localSignerIds,
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
    AsyncValue<List<MultisigProposal>> pastProposalsAsync,
  ) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
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
            Text(l10n.homeActivityErrorLoading, style: text.caption.copyWith(color: colors.semanticEmber)),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onRetry?.call(),
              child: Text(
                l10n.homeActivityRetry,
                style: text.body.copyWith(color: colors.textContent, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
      data: (data) {
        final merged = multisigActivityOf(
          ref.read(transactionServiceProvider),
          data,
          pastProposalsAsync.value ?? const [],
          msig,
        );
        final recent = merged.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(l10n.homeActivityTitle, style: text.headingRow.copyWith(color: colors.textContent)),
            const SizedBox(height: 12),
            SwapActivityRow(isHidden: isHidden),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.homeActivityEmptyTitle,
                  textAlign: TextAlign.center,
                  style: text.body.copyWith(color: colors.textMuted),
                ),
              )
            else
              ...recent.mapIndexed((index, tx) {
                final itemData = TxItemData.from(tx, msig.accountId, context.colorsV3, l10n);
                return buildTxItem(
                  tx,
                  itemData,
                  context.colorsV3,
                  context.themeTextV3,
                  context.radiusV3,
                  l10n,
                  formattedAmount: txItemAmountText(itemData, formatTxAmount, isHidden: isHidden),
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
