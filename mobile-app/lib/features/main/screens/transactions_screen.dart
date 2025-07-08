import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';

class TransactionsScreen extends StatefulWidget {
  final String initialAccountId;

  const TransactionsScreen({super.key, required this.initialAccountId});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final ChainHistoryService _chainHistoryService = ChainHistoryService();
  final ScrollController _scrollController = ScrollController();

  List<TransactionEvent> _transactions = [];
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
      final result = await _chainHistoryService.fetchAllTransfers(
        accountId: widget.initialAccountId,
        limit: _limit,
        offset: 0,
      );
      setState(() {
        _transactions = result.combinedTransfers;
        _hasMore = result.hasMore;
        _offset = result.nextOffset;
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
      final result = await _chainHistoryService.fetchAllTransfers(
        accountId: widget.initialAccountId,
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _transactions.addAll(result.combinedTransfers);
        _hasMore = result.hasMore;
        _offset = result.nextOffset;
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
      appBar: AppBar(title: const Text('All Transactions'), backgroundColor: const Color(0xFF0E0E0E), elevation: 0),
      backgroundColor: const Color(0xFF0E0E0E),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_transactions.isEmpty) {
      return const Center(
        child: Text('No transactions found.', style: TextStyle(color: Colors.white)),
      );
    }

    // Note: RecentTransactionsList is not designed for infinite scrolling out of the box.
    // This implementation wraps it in a ListView and adds a progress indicator at the bottom.
    return ListView(
      controller: _scrollController,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: RecentTransactionsList(transactions: _transactions, currentWalletAddress: widget.initialAccountId),
        ),
        if (_hasMore)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
