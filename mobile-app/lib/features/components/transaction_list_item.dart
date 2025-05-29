import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final bool isReceived;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.isReceived,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isReceived ? Colors.green.useOpacity(0.2) : Colors.red.useOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isReceived ? Icons.arrow_downward : Icons.arrow_upward,
          color: isReceived ? Colors.green : Colors.red,
        ),
      ),
      title: Text(
        isReceived ? 'Received' : 'Sent',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        transaction.otherParty,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isReceived ? '+' : '-'}${NumberFormattingService().formatBalance(transaction.amount)} REZ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isReceived ? Colors.green : Colors.red,
            ),
          ),
          Text(
            transaction.status.name,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
