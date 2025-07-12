import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resonance_network_wallet/features/main/services/wallet_state_manager.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      Provider.of<WalletStateManager>(context, listen: false).loadMoreTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFE6E6E6)),
        centerTitle: false,
        title: const Text(
          'Transaction History',
          style: TextStyle(
            color: Color(0xFFE6E6E6),
            fontSize: 16,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: const Color(0xFF0E0E0E),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0E0E0E),
      body: Consumer<WalletStateManager>(
        builder: (context, manager, child) {
          if (manager.isLoading && manager.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (manager.error != null) {
            return Center(
              child: Text(manager.error!, style: const TextStyle(color: Colors.red)),
            );
          }
          if (manager.transactions.isEmpty) {
            return const Center(
              child: Text('No transactions found.', style: TextStyle(color: Colors.white)),
            );
          }

          return RefreshIndicator(
            onRefresh: manager.refresh,
            child: ListView(
              controller: _scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RecentTransactionsList(
                    transactions: manager.transactions,
                    currentWalletAddress: '', // Fetch from settings if needed
                  ),
                ),
                if (manager.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
