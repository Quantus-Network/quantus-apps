import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/get_started.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:resonance_network_wallet/features/components/transactions_list.dart';
import 'package:resonance_network_wallet/features/main/screens/transactions_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';

class HistorySection extends ConsumerStatefulWidget {
  final AsyncValue<CombinedTransactionsList> allTransactionsAsync;
  final BaseAccount activeAccount;
  final Future<void> Function()? onRetry;

  const HistorySection({super.key, required this.allTransactionsAsync, required this.activeAccount, this.onRetry});

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  @override
  Widget build(BuildContext context) {
    return widget.allTransactionsAsync.when(
      data: (combinedData) {
        final txService = ref.read(transactionServiceProvider);
        // Combine and deduplicate all transaction types
        final allTransactions = txService.combineAndDeduplicateTransactions(
          pendingCancellationIds: combinedData.pendingCancellationIds,
          pendingTransactions: combinedData.pendingTransactions,
          reversibleTransfers: combinedData.reversibleTransfers,
          otherTransfers: combinedData.otherTransfers,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (allTransactions.isEmpty) const GetStarted(),

            if (allTransactions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 10.0, bottom: 10.0),
                child: Text(
                  'Recent Transactions',
                  style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.light),
                ),
              ),
              if (widget.allTransactionsAsync.isRefreshing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: LinearProgressIndicator()),
                ),
              RecentTransactionsList(
                backgroundColor: const Color(0x80000000),
                transactions: allTransactions.take(4).toList(),
                accountIds: [widget.activeAccount.accountId],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 12.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionsScreen(
                            showAccountFilter: false,
                            fixedAccountId: widget.activeAccount.accountId,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Transaction History →',
                      style: context.themeText.detail?.copyWith(
                        color: context.themeColors.textPrimary.useOpacity(0.80),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: Colors.black.withAlpha(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: _buildLoader()),
      ),
      error: (error, stack) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(
          color: Colors.black.withAlpha(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error.toString(),
                style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Button(
                variant: ButtonVariant.neutral,
                label: 'Retry',
                onPressed: () async {
                  widget.onRetry?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      children: [
        const TransactionSkeleton(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(color: context.themeColors.darkGray, thickness: 1),
        ),
        const TransactionSkeleton(),
      ],
    );
  }
}
