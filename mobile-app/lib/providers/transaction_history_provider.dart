import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';

class TransactionHistoryProvider with ChangeNotifier {
  final ChainHistoryService _chainHistoryService;
  final SettingsService _settingsService;
  final WalletStateManager _walletStateManager;

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

  Future<void> fetchInitialTransactions() async {
    if (_walletStateManager.walletData.data == null) {
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
