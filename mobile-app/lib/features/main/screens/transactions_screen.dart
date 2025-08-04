import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/transactions_list.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginationControllerProvider.notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WalletAppBar(title: 'Transaction History'),
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final allTransactionsAsync = ref.watch(allTransactionsProvider);
    final activeAccountAsync = ref.watch(activeAccountProvider);

    if (activeAccountAsync.value == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeAccount = activeAccountAsync.value!;

    return allTransactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          error.toString(),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (combinedData) {
        // Combine all transaction types for display
        final allTransactions = <TransactionEvent>[
          ...combinedData.pendingTransactions.cast<TransactionEvent>(),
          ...combinedData.reversibleTransfers.cast<TransactionEvent>(),
          ...combinedData.otherTransfers,
        ];

        if (allTransactions.isEmpty) {
          return const Center(
            child: Text(
              'No transactions found.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allTransactionsProvider),
          child: ListView(
            controller: _scrollController,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: RecentTransactionsList(
                  transactions: allTransactions,
                  currentWalletAddress: activeAccount.accountId,
                ),
              ),
              if (ref.watch(paginationControllerProvider).hasMore)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
