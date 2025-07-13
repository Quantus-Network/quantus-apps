import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/wallet_data.dart';
import 'package:flutter/foundation.dart'; // Added for ChangeNotifier

class LoadingState<T> {
  T? data;
  bool isLoading;
  String? error;
  Future<T> loadData;

  bool get hasData => data != null;
  bool get hasError => error != null;

  LoadingState({this.data, this.isLoading = false, this.error, required this.loadData});

  Future<LoadingState<T>> load() async {
    isLoading = true;
    try {
      data = await loadData;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
    return this;
  }
}

class WalletStateManager with ChangeNotifier {
  final SettingsService _settingsService;
  final ChainHistoryService _chainHistoryService;
  final SubstrateService _substrateService;

  late LoadingState<SortedTransactionsList?> txData;
  late LoadingState<WalletData?> walletData;

  WalletStateManager(this._chainHistoryService, this._settingsService, this._substrateService) {
    txData = LoadingState(loadData: _fetchTransactionHistory());
    walletData = LoadingState(loadData: _fetchBalance());
  }

  Future<SortedTransactionsList?> _fetchTransactionHistory() async {
    final accountId = await _settingsService.getAccountId();
    final result = await _chainHistoryService.fetchAllTransactionTypes(accountId: accountId!, limit: 20, offset: 0);
    return result;
  }

  Future<WalletData?> _fetchBalance() async {
    const Duration networkTimeout = Duration(seconds: 15);
    final accountId = await _settingsService.getAccountId();
    final balance = await _substrateService.queryBalance(accountId!).timeout(networkTimeout);
    return WalletData(accountId: accountId, walletName: '', balance: balance);
  }

  Future<void> load() async {
    await Future.wait([txData.load(), walletData.load()]);
    notifyListeners();
  }

  Future<void> refreshTransactions() async {
    txData = LoadingState(loadData: _fetchTransactionHistory());
    await txData.load();
    notifyListeners();
  }

  Future<void> loadMoreTransactions({required String accountId, required int limit, required int offset}) async {
    final result = await _chainHistoryService.fetchAllTransactionTypes(
      accountId: accountId,
      limit: limit,
      offset: offset,
    );
    if (txData.data == null) {
      txData.data = result;
    } else {
      txData.data!.otherTransfers.addAll(result.otherTransfers);
      // Add similar for other transaction types if present in SortedTransactionsList (e.g., reversibleTransfers.addAll(result.reversibleTransfers);)
    }
    notifyListeners();
  }
}
