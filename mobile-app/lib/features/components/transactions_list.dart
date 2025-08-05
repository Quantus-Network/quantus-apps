import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<TransactionEvent> transactions;
  final List<String>
  accountIds; // List of account IDs we're showing transactions for
  final bool Function(TransactionEvent)? filter;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.accountIds,
    this.filter,
  });

  /// Determines which account "owns" a transaction for display purposes
  String _getOwnerAccountId(TransactionEvent transaction) {
    // If showing only one account, it's always the owner
    if (accountIds.length == 1) {
      return accountIds.first;
    }

    // For multiple accounts (All Accounts view), prefer the sender if it's in
    // our list
    if (accountIds.contains(transaction.from)) {
      return transaction.from;
    }

    // Otherwise use the receiver if it's in our list
    if (accountIds.contains(transaction.to)) {
      return transaction.to;
    }

    // Fallback to first account (shouldn't happen in normal cases)
    return accountIds.first;
  }

  @override
  Widget build(BuildContext context) {
    final transactionsToShow = filter == null
        ? transactions
        : transactions.where(filter!).toList();

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
        color: const Color(0x3F000000), // black w/ alpha
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transactionsToShow.isEmpty)
              const Text(
                'No transactions yet.',
                style: TextStyle(color: Colors.white, fontFamily: 'Fira Code'),
              )
            else ...[
              if (scheduled.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scheduled.length,
                  itemBuilder: (context, index) {
                    final transaction = scheduled[index];
                    return TransactionListItem(
                      key: ValueKey(transaction.id),
                      transaction: transaction,
                      ownerAccountId: _getOwnerAccountId(transaction),
                    );
                  },
                  separatorBuilder: (context, index) => const _Divider(),
                ),
              if (scheduled.isNotEmpty && others.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: Colors.white, thickness: 1),
                ),
              if (others.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: others.length,
                  itemBuilder: (context, index) {
                    final transaction = others[index];
                    return TransactionListItem(
                      key: ValueKey(transaction.id),
                      transaction: transaction,
                      ownerAccountId: _getOwnerAccountId(transaction),
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
