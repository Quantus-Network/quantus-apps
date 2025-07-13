import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/sorted_transactions.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart'; // Ensure import

class TransactionsScreen extends StatefulWidget {
  final WalletStateManager manager;

  const TransactionsScreen({super.key, required this.manager});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ScrollController _scrollController = ScrollController();

  SortedTransactionsList? _transactions;
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_updateState);
    _updateState(); // Set initial state from manager
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_updateState);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateState() {
    setState(() {
      _isLoading = widget.manager.txData.isLoading;
      _error = widget.manager.txData.error;
      _transactions = widget.manager.txData.data;
      if (_transactions != null && _offset == 0) {
        // On initial/refresh, update pagination info
        _offset = _transactions!.otherTransfers.length;
        _hasMore = _transactions!.otherTransfers.length == _limit;
      }
    });
  }

  Future<void> _fetchMoreTransactions() async {
    if (!_hasMore || _isLoading) return;

    final oldLength = _transactions?.otherTransfers.length ?? 0;
    final accountId = widget.manager.walletData.data!.accountId;

    await widget.manager.loadMoreTransactions(accountId: accountId, limit: _limit, offset: _offset);

    // No need for setState; listener will trigger _updateState
    // But calculate hasMore/offset here if needed (listener updates _transactions)
    final added = _transactions!.otherTransfers.length - oldLength;
    _offset += added;
    _hasMore = added == _limit;
  }

  Future<void> _refreshTransactions() async {
    _offset = 0;
    _hasMore = true;
    _error = null;
    await widget.manager.refreshTransactions();
    // Listener will handle UI update
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchMoreTransactions();
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _transactions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_transactions?.combined.isEmpty ?? true) {
      return const Center(
        child: Text('No transactions found.', style: TextStyle(color: Colors.white)),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTransactions,
      child: ListView(
        controller: _scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: RecentTransactionsList(
              transactions: _transactions!.combined,
              currentWalletAddress: widget.manager.walletData.data!.accountId,
            ),
          ),
          if (_isLoading && _hasMore)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
