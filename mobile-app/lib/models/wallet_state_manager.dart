import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/wallet_data.dart';
import 'package:resonance_network_wallet/models/pending_transfer_event.dart';
import 'package:polkadart/polkadart.dart';

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
      if (tx.state != TransactionState.inHistory && tx.state != TransactionState.failed) {
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
    updatePendingTransactions();
    notifyListeners();
  }

  // Update pending transactions - see if any have been resolved in the history list, and remove
  // them accordingly as they are coming in with chain history.
  bool updatePendingTransactions() {
    bool updated = false;
    var transferList = txData.data?.combined ?? [];
    for (var pending in pendingTransactions) {
      if (pending.extrinsicHash != null) {
        print("pending ${pending.amount} extrinsic hash: ${pending.extrinsicHash}");

        for (var transfer in transferList) {
          print("checking trasfer ${transfer.amount} with tx hash: ${transfer.extrinsicHash}");
          if (transfer.extrinsicHash == pending.extrinsicHash) {
            pending.state = TransactionState.inHistory;
            pendingTransactions.remove(pending);
            updated = true;
          }
        }
      }
    }
    return updated;
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

  PendingTransactionEvent createPendingTransaction({
    required String from,
    required String to,
    required BigInt amount,
    DateTime? scheduledAt,
    bool isOutgoing = true,
    bool isReversible = false,
    BigInt? fee,
  }) {
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
      scheduledAt: scheduledAt,
    );
    return pending;
  }

  void addPendingTransaction(PendingTransactionEvent pending) {
    pendingTransactions.add(pending);
    notifyListeners();
  }

  // TODO: this should update the state of the pending transfer to one of
  // * ready
  // * broadcast
  // * in block
  // * failed
  void updatePending(String PendingID, String Status) {}

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (pendingTransactions.isEmpty) return;
      // TODO see if we need this - we need to get the history as long as we have pending tx, and resolve them.

      notifyListeners();
    });
  }

  Future<String> balanceTransfer(String senderSeed, String targetAddress, BigInt amount) async {
    final pending = createPendingTransaction(from: senderSeed, to: targetAddress, amount: amount);
    addPendingTransaction(pending);

    void onStatus(ExtrinsicStatus status) {
      String? hash;
      TransactionState newState;
      switch (status.type) {
        case 'ready':
          newState = TransactionState.ready;
          break;
        case 'broadcast':
          newState = TransactionState.broadcast;
          break;
        case 'inBlock':
          newState = TransactionState.inBlock;
          hash = status.value;
          break;
        default:
          print("Error: unexpected status ${status.type}");
          newState = TransactionState.failed;
          pending.error = 'Unknown status ${status.type}';
      }
      updatePendingTransaction(pending.id, newState, extrinsicHash: hash);
      if (newState == TransactionState.inBlock && hash != null) {
        _startPollingForHistory();
      }
    }

    try {
      await BalancesService().balanceTransfer(senderSeed, targetAddress, amount, onStatus);
    } catch (e, stackTrace) {
      updatePendingTransaction(pending.id, TransactionState.failed, error: e.toString());
      print('Failed to transfer balance: $e');
      print('Failed to transfer balance: $stackTrace');
      throw Exception('Failed to transfer balance: $e');
    }
    return pending.id;
  }

  Future<void> scheduleReversibleTransferWithDelaySeconds({
    required String senderSeed,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
  }) async {
    // convert seconds to milliseconds for runtime
    final pending = createPendingTransaction(from: senderSeed, to: recipientAddress, amount: amount);
    addPendingTransaction(pending);
    void onStatus(ExtrinsicStatus status) {
      String? hash;
      TransactionState newState;
      switch (status.type) {
        case 'ready':
          newState = TransactionState.ready;
          break;
        case 'broadcast':
          newState = TransactionState.broadcast;
          break;
        case 'inBlock':
          newState = TransactionState.inBlock;
          hash = status.value;
          break;
        default:
          newState = TransactionState.failed;
          pending.error = 'Unknown status';
      }
      updatePendingTransaction(pending.id, newState, extrinsicHash: hash);
      if (newState == TransactionState.inBlock && hash != null) {
        _startPollingForHistory();
      }
    }

    await ReversibleTransfersService().scheduleReversibleTransferWithDelaySeconds(
      senderSeed: senderSeed,
      recipientAddress: recipientAddress,
      amount: amount,
      delaySeconds: delaySeconds,
      onStatus: onStatus,
    );
  }

  void updatePendingTransaction(String id, TransactionState newState, {String? extrinsicHash, String? error}) {
    final tx = pendingTransactions.firstWhere(
      (tx) => tx.id == id,
      orElse: () => throw Exception('Pending TX not found'),
    );
    tx.state = newState;
    if (extrinsicHash != null) {
      tx.extrinsicHash = extrinsicHash;
    }
    if (error != null) {
      tx.error = error;
    }
    notifyListeners();
  }

  Timer? _historyPollTimer;

  void _startPollingForHistory() {
    const pollInterval = Duration(seconds: 10);
    final startTime = DateTime.now();

    if (pendingTransactions.isEmpty) {
      return;
    }
    _historyPollTimer = Timer.periodic(pollInterval, (timer) async {
      try {
        await refreshTransactions();
      } catch (e) {
        print('error fetching transaction history: $e');
      }
    });

    // _pollTimers[pendingId] = Timer.periodic(pollInterval, (timer) async {
    //   if (DateTime.now().difference(startTime) > maxDuration) {
    //     updatePendingTransaction(pendingId, TransactionState.failed, error: 'History inclusion timeout');
    //     timer.cancel();
    //     _pollTimers.remove(pendingId);
    //     return;
    //   }

    //   try {
    //     await refreshTransactions(); // Poll recent history
    //     final historyTx = txData.data?.combined.firstWhere(
    //       (tx) => tx.extrinsicHash == extrinsicHash,
    //       orElse: () => null,
    //     );
    //     if (historyTx != null) {
    //       // Merge: Add if not already (though refresh might), update with real data
    //       final pending = pendingTransactions.firstWhere((tx) => tx.id == pendingId);
    //       // Optionally copy real fields to pending or directly add historyTx
    //       txData.data!.combined.add(historyTx); // Ensure added
    //       pendingTransactions.remove(pending);
    //       updatePendingTransaction(pendingId, TransactionState.inHistory);
    //       await _fetchBalance(); // Refresh balance
    //       notifyListeners();
    //       timer.cancel();
    //       _pollTimers.remove(pendingId);
    //     }
    //   } catch (e) {
    //     // Log error, continue polling
    //   }
    // });
  }
}
