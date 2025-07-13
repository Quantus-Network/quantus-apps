import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/wallet_data.dart';
import 'package:resonance_network_wallet/models/pending_transfer_event.dart';

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

  List<PendingTransactionEvent> pendingTransactions = [];
  Timer? _pollingTimer;

  WalletStateManager(this._chainHistoryService, this._settingsService, this._substrateService) {
    txData = LoadingState(loadData: _fetchTransactionHistory());
    walletData = LoadingState(loadData: _fetchBalance());
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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

  BigInt get estimatedBalance {
    if (!walletData.hasData) return BigInt.zero;
    BigInt base = walletData.data!.balance;
    for (var tx in pendingTransactions) {
      if (tx.state != TransactionState.includedInHistory && tx.state != TransactionState.failed) {
        final adjustment = (tx.from == walletData.data!.accountId) ? -tx.amount : tx.amount;
        base += adjustment;
      }
    }
    return base;
  }

  List<TransactionEvent> get combinedTransactions {
    final fetched = txData.data?.combined ?? [];
    final all = [...fetched, ...pendingTransactions];
    all.sort((a, b) {
      final tsA = a.timestamp;
      final tsB = b.timestamp;
      return tsB.compareTo(tsA);
    });
    return all;
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
    }
    notifyListeners();
  }

  Future<PendingTransactionEvent> addPendingTransaction({
    required String from,
    required String to,
    required BigInt amount,
    bool isOutgoing = true,
    bool isReversible = false,
    BigInt? fee,
  }) async {
    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now();
    final pending = PendingTransactionEvent(
      tempId: tempId,
      from: from,
      to: to,
      amount: amount,
      timestamp: timestamp,
      isReversible: isReversible,
      fee: fee ?? BigInt.zero,
    );
    if (isReversible) {
      pending.scheduledAt = timestamp.add(const Duration(hours: 24));
    }
    pendingTransactions.add(pending);
    notifyListeners();
    return pending;
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (pendingTransactions.isEmpty) return;

      for (var tx in List.from(pendingTransactions)) {
        await _updateTxState(tx);
      }
      notifyListeners();
    });
  }

  Future<void> _updateTxState(PendingTransactionEvent tx) async {
    try {
      final inclusionStatus = await _substrateService.checkTxInclusion(tx.extrinsicHash ?? '');
      if (inclusionStatus.included) {
        tx.state = TransactionState.includedInBlock;
        tx.blockNumber = inclusionStatus.blockNumber;
        if (tx.isReversible && tx.txId == null) {
          tx.txId = _parseTxIdFromEvents(inclusionStatus.events);
        }
      }

      if (tx.state == TransactionState.includedInBlock) {
        final historyItem = await _chainHistoryService.fetchTxById(tx.txId ?? tx.extrinsicHash ?? '');
        if (historyItem != null) {
          tx.state = TransactionState.includedInHistory;
          if (historyItem is ReversibleTransferEvent) {
            txData.data?.combined.add(historyItem);
          } else if (historyItem is TransferEvent) {
            txData.data?.combined.add(historyItem);
          }
          pendingTransactions.remove(tx);
          walletData = LoadingState(loadData: _fetchBalance());
          await walletData.load();
        }
      }
    } catch (e) {
      tx.state = TransactionState.failed;
      tx.error = e.toString();
      notifyListeners();
    }
  }

  String? _parseTxIdFromEvents(List<dynamic> events) {
    for (var event in events) {
      if (event['type'] == 'ReversibleTransfer' && event['action'] == 'created') {
        return event['txId'] as String?;
      }
    }
    return null;
  }
}
