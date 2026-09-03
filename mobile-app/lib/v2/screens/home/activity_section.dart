import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/skeleton.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/activity/activity_screen.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';

class ActivitySection extends ConsumerStatefulWidget {
  final AsyncValue<CombinedTransactionsList> txAsync;
  final BaseAccount activeAccount;
  final Future<void> Function()? onRetry;

  /// Masks the listed amounts. Passed down by the home screen, which owns the
  /// hide-balances toggle.
  final bool isHidden;

  const ActivitySection({
    super.key,
    required this.txAsync,
    required this.activeAccount,
    this.onRetry,
    this.isHidden = false,
  });

  @override
  ConsumerState<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends ConsumerState<ActivitySection> {
  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final formatTxAmount = ref.watch(txAmountDisplayProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return widget.txAsync.when(
      data: (data) {
        final txService = ref.read(transactionServiceProvider);
        final all = txService.combineAndDeduplicateTransactions(
          pendingCancellationIds: data.pendingCancellationIds,
          pendingTransactions: data.pendingTransactions,
          pendingMultisigCreations: data.pendingMultisigCreations,
          pendingMultisigProposals: data.pendingMultisigProposals,
          pendingMultisigExecutions: data.pendingMultisigExecutions,
          pendingMultisigCancellations: data.pendingMultisigCancellations,
          scheduledReversibleTransfers: data.scheduledReversibleTransfers,
          otherTransfers: data.otherTransfers,
        );
        final recentTransactions = all.take(5).toList();
        var pendingSendKeyAssigned = false;

        if (all.isEmpty) {
          return Column(children: [const SizedBox(height: 40), _header(l10n), _emptyState(l10n)]);
        }

        final isPrivate = isEncryptedAccount(widget.activeAccount);

        return Column(
          children: [
            const SizedBox(height: 40),
            _header(l10n),
            const SizedBox(height: 28),

            ...recentTransactions.mapIndexed((index, tx) {
              final data = TxItemData.from(tx, widget.activeAccount.accountId, colors, l10n, isPrivate: isPrivate);
              final isLastItem = index == recentTransactions.length - 1;
              Key? itemKey;
              if (!pendingSendKeyAssigned &&
                  tx is PendingTransactionEvent &&
                  tx.from == widget.activeAccount.accountId) {
                itemKey = const Key(E2EKeys.homePendingSendActivityItem);
                pendingSendKeyAssigned = true;
              }

              return buildTxItem(
                tx,
                data,
                colors,
                text,
                context.radiusV3,
                l10n,
                formattedAmount: txItemAmountText(data, formatTxAmount, isHidden: widget.isHidden),
                isLastItem: isLastItem,
                itemKey: itemKey,
                onTap: () {
                  showTransactionDetailSheet(context, tx, widget.activeAccount.accountId);
                },
              );
            }),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(l10n),
            const SizedBox(height: 24),
            for (var i = 0; i < 3; i++) ...[
              const TxItemSkeleton(),
              if (i < 2) Divider(color: colors.borderHairline, height: 24),
            ],
          ],
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Text(l10n.homeActivityErrorLoading, style: text.caption.copyWith(color: colors.semanticEmber)),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.invalidate(activeAccountTransactionsProvider);
                widget.onRetry?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  l10n.homeActivityRetry,
                  style: text.body.copyWith(color: colors.textContent, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(l10n.homeActivityEmptyTitle, style: text.bodyLarge.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              l10n.homeActivityEmptyMessage(AppConstants.tokenSymbol),
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.homeActivityTitle, style: text.titleScreen.copyWith(color: colors.textContent)),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen())),
          child: Text(l10n.homeActivityViewAll, style: text.amountRow.copyWith(color: colors.textMuted)),
        ),
      ],
    );
  }
}
