import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/sorted_transactions.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';

class TransactionsScreen extends StatefulWidget {
  final String initialAccountId;

  const TransactionsScreen({super.key, required this.initialAccountId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ChainHistoryService _chainHistoryService = ChainHistoryService();
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
    _fetchInitialTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _chainHistoryService.fetchAllTransactionTypes(
        accountId: widget.initialAccountId,
        limit: _limit,
        offset: 0,
      );
      setState(() {
        _transactions = result;
        _hasMore = result.otherTransfers.length == _limit;
        _offset = result.otherTransfers.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load transactions.';
      });
    }
  }

  Future<void> _fetchMoreTransactions() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _chainHistoryService.fetchAllTransactionTypes(
        accountId: widget.initialAccountId,
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _transactions!.otherTransfers.addAll(result.otherTransfers);
        _hasMore = result.otherTransfers.length == _limit;
        _offset += result.otherTransfers.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Optionally show an error for loading more
      });
    }
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
    if (_transactions!.combined.isEmpty) {
      return const Center(
        child: Text('No transactions found.', style: TextStyle(color: Colors.white)),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchInitialTransactions,
      child: ListView(
        controller: _scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: RecentTransactionsList(
              transactions: _transactions!.combined,
              currentWalletAddress: widget.initialAccountId,
            ),
          ),
          if (_hasMore)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
