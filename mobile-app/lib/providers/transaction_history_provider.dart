import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';

class TransactionHistoryProvider with ChangeNotifier {
  final ChainHistoryService _chainHistoryService;
  final SettingsService _settingsService;
  final WalletStateManager _walletStateManager;
  Timer? _pollingTimer;

  StreamSubscription<List<Account>>? _accountsSubscription;

  TransactionHistoryProvider({
    required ChainHistoryService chainHistoryService,
    required SettingsService settingsService,
    required WalletStateManager walletStateManager,
  }) : _chainHistoryService = chainHistoryService,
       _settingsService = settingsService,
       _walletStateManager = walletStateManager {
    // Listen to account changes
    _accountsSubscription = _settingsService.accountsStream.listen((accounts) {
      _accounts = accounts;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _accountsSubscription?.cancel();
    _pollingTimer?.cancel();

    super.dispose();
  }

  List<Account> _accounts = [];
  List<Account> get accounts => _accounts;

  List<TransactionEvent> _transactions = [];
  List<TransactionEvent> get transactions => _transactions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _error;
  String? get error => _error;

  int _offset = 0;
  int _pageSize = AppConstants.defaultPageSize;
  int get pageSize => _pageSize;

  List<String> _accoundIds = [];

  Future<void> _pollForNewTransactions() async {
    // Don't poll if a fetch is already in progress or wallet is not ready
    if (_isLoading ||
        _walletStateManager.walletData == null ||
        _accoundIds.isEmpty) {
      return;
    }

    try {
      final result = await _chainHistoryService.fetchAllTransactionTypes(
        accountIds: _accoundIds,
        limit: _pageSize, // Fetch one page to check for new items
        offset: 0,
      );

      if (result.combined.isNotEmpty) {
        final existingTxIds = _transactions.map((tx) => tx.id).toSet();
        final trulyNewTransactions = result.combined
            .where((tx) => !existingTxIds.contains(tx.id))
            .toList();

        if (trulyNewTransactions.isNotEmpty) {
          _transactions.insertAll(0, trulyNewTransactions);
          _offset +=
              trulyNewTransactions.length; // Adjust offset for pagination
          notifyListeners();
        }
      }
    } catch (e) {
      // Silently ignore polling errors to not disturb the user
      print('Error during transaction polling: $e');
    }
  }

  void startPolling() {
    stopPolling(); // Ensure no multiple timers are running
    _pollingTimer = Timer.periodic(
      const Duration(seconds: AppConstants.pollingIntervalSeconds),
      (_) {
        _pollForNewTransactions();
      },
    );
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> fetchInitialTransactions() async {
    if (_walletStateManager.walletData == null) {
      await _walletStateManager.load();
    }

    if (_accounts.isEmpty) {
      _accounts = await _settingsService.getAccounts();
      _accoundIds = _accounts.map((a) => a.accountId).toList();
    }

    _offset = 0;
    _transactions = [];
    _hasMore = true;

    await _fetchTransactions();
  }

  Future<void> fetchMoreTransactions() async {
    if (_isLoading || !_hasMore) return;
    await _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _chainHistoryService.fetchAllTransactionTypes(
        accountIds: _accoundIds,
        limit: _pageSize,
        offset: _offset,
      );

      final newTransactions = result.combined;

      if (newTransactions.length < _pageSize) {
        _hasMore = false;
      }

      _offset += newTransactions.length;
      _transactions.addAll(newTransactions);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTransactions() async {
    _offset = 0;
    _transactions = [];
    _hasMore = true;
    await _fetchTransactions();
  }

  Future<void> refreshAccountList(List<Account> accounts) async {
    _accounts = await _settingsService.getAccounts();
    notifyListeners();
  }

  void setPageSize(int newSize) {
    _pageSize = newSize;
    refreshTransactions();
  }

  void setAccountIds(List<String> ids) {
    _accoundIds = ids;
    refreshTransactions();
  }
}
