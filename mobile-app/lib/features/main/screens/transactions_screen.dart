import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';

class TransactionsScreen extends StatefulWidget {
  final List<TransactionEvent> allTransactions;
  final String currentWalletAddress;

  const TransactionsScreen({super.key, required this.allTransactions, required this.currentWalletAddress});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool Function(TransactionEvent)? _currentFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions'), backgroundColor: const Color(0xFF0E0E0E), elevation: 0),
      backgroundColor: const Color(0xFF0E0E0E),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: RecentTransactionsList(
                transactions: widget.allTransactions,
                currentWalletAddress: widget.currentWalletAddress,
                filter: _currentFilter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
