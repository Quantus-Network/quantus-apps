import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';

class RecentTransactionsList extends ConsumerWidget {
  final List<TransactionEvent> transactions;
  final List<String> accountIds; // List of account IDs we're showing transactions for
  final bool Function(TransactionEvent)? filter;
  final Color backgroundColor;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.accountIds,
    required this.backgroundColor,
    this.filter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txService = ref.read(transactionServiceProvider);
    final transactionsToShow = filter == null ? transactions : transactions.where(filter!).toList();

    final scheduled = transactionsToShow
        .whereType<ReversibleTransferEvent>()
        .where((tx) => tx.status == ReversibleTransferStatus.SCHEDULED)
        .toList();

    final others = transactionsToShow.where((tx) {
      if (tx is ReversibleTransferEvent) {
        return tx.status != ReversibleTransferStatus.SCHEDULED;
      }
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transactionsToShow.isEmpty)
              SizedBox(
                width: double.infinity,
                child: Text('No transactions yet.', style: context.themeText.smallParagraph),
              )
            else ...[
              if (scheduled.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: scheduled.length,
                  itemBuilder: (context, index) {
                    final transaction = scheduled[index];
                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 7.0 : 0),
                      child: TransactionListItem(
                        key: ValueKey(transaction.id),
                        transaction: transaction,
                        role: txService.getTransactionRole(transaction, accountIds: accountIds),
                        showFromAndTo: accountIds.length > 1,
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const _Divider(),
                ),
              if (scheduled.isNotEmpty && others.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7.0),
                  child: Divider(color: context.themeColors.darkGray, thickness: 1),
                ),
              if (others.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: others.length,
                  itemBuilder: (context, index) {
                    final transaction = others[index];
                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 7.0 : 0),
                      child: TransactionListItem(
                        key: ValueKey(transaction.id),
                        transaction: transaction,
                        role: txService.getTransactionRole(transaction, accountIds: accountIds),
                        showFromAndTo: accountIds.length > 1,
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const _Divider(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 7.0),
      child: Divider(
        color: Color(0x26FFFFFF), // white w/ alpha
        height: 1,
      ),
    );
  }
}
