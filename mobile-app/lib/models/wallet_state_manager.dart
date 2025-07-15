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
  Future<T> Function() loadData;

  bool get hasData => data != null;
  bool get hasError => error != null;

  LoadingState({this.data, this.isLoading = false, this.error, required this.loadData});

  Future<LoadingState<T>> load({bool quiet = false}) async {
    if (!quiet) {
      isLoading = true;
    }
    error = null;
    try {
      data = await loadData();
    } catch (e) {
      error = e.toString();
      print('Load error: $e');
    } finally {
      if (!quiet) {
        isLoading = false;
      }
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
    txData = LoadingState(loadData: _fetchTransactionHistory);
    walletData = LoadingState(loadData: _fetchBalance);
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
      if (tx.transactionState != TransactionState.inHistory && tx.transactionState != TransactionState.failed) {
        final isSend = tx.from == walletData.data!.accountId;
        final adjustment = isSend ? -tx.amount : tx.amount;
        base += adjustment;
        if (isSend && tx.fee != null) {
          base -= tx.fee!;
        }
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

  Future<void> load({bool quiet = false}) async {
    await Future.wait([txData.load(quiet: quiet), walletData.load(quiet: quiet)]);
    updatePendingTransactions();
    notifyListeners();
  }

  Future<void> refreshTransactions({bool quiet = false}) async {
    await txData.load(quiet: quiet);
    updatePendingTransactions();
    notifyListeners();
  }

  // Update pending transactions - see if any have been resolved in the history list, and remove
  // them accordingly as they are coming in with chain history.
  bool updatePendingTransactions() {
    bool updated = false;
    var transferList = txData.data?.combined ?? [];
    List<PendingTransactionEvent> toRemove = [];
    for (var pending in pendingTransactions) {
      if (pending.blockHash != null) {
        print('pending ${pending.amount} block hash: ${pending.blockHash}');

        for (var transfer in transferList) {
          print('checking trasfer ${transfer.amount} with block hash: ${transfer.blockHash}');
          if (transfer.blockHash == pending.blockHash) {
            print('found item block hash - removing');
            toRemove.add(pending);
            updated = true;
          }
        }
      }
    }
    if (toRemove.isNotEmpty) {
      pendingTransactions.removeWhere((tx) => toRemove.contains(tx));
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
    required BigInt fee,
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
      fee: fee,
      scheduledAtTime: scheduledAt,
    );
    return pending;
  }

  void addPendingTransaction(PendingTransactionEvent pending) {
    pendingTransactions.add(pending);
    notifyListeners();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (pendingTransactions.isEmpty) return;
      notifyListeners();
    });
  }

  String _senderAddressFromSeed(String senderSeed) {
    return SubstrateService().dilithiumKeypairFromMnemonic(senderSeed).ss58Address;
  }

  Future<String> balanceTransfer(String senderSeed, String targetAddress, BigInt amount, BigInt feeEstimate) async {
    final pending = createPendingTransaction(
      from: _senderAddressFromSeed(senderSeed),
      to: targetAddress,
      amount: amount,
      fee: feeEstimate,
    );
    addPendingTransaction(pending);

    StreamSubscription<ExtrinsicStatus>? subscription;

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
        case 'finalized':
          print('unexpected finalized status.');
          // we want to stop listening to history tx long before this.
          newState = TransactionState.inBlock;
          break;
        default:
          print('Error: unexpected status ${status.type}');
          newState = TransactionState.failed;
          pending.error = 'Unknown status ${status.type}';
      }
      updatePendingTransaction(pending.id, newState, blockHash: hash);
      if (newState == TransactionState.inBlock && hash != null) {
        _startPollingForHistory();
        subscription?.cancel();
      }
    }

    try {
      subscription = await BalancesService().balanceTransfer(senderSeed, targetAddress, amount, onStatus);
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
    required BigInt feeEstimate,
  }) async {
    final pending = createPendingTransaction(
      from: _senderAddressFromSeed(senderSeed),
      to: recipientAddress,
      amount: amount,
      fee: feeEstimate,
    );
    addPendingTransaction(pending);
    StreamSubscription<ExtrinsicStatus>? subscription;

    // update function for the ephemeral pending event
    void onStatus(ExtrinsicStatus status) {
      String? blockHash;
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
          blockHash = status.value;
          break;
        case 'finalized':
          print('unexpected finalized status.');
          // we want to stop listening to history tx long before this.
          newState = TransactionState.inBlock;
          break;
        default:
          newState = TransactionState.failed;
          pending.error = 'Unknown status';
      }
      updatePendingTransaction(pending.id, newState, blockHash: blockHash);
      if (newState == TransactionState.inBlock) {
        _startPollingForHistory();
        subscription?.cancel();
      }
    }

    subscription = await ReversibleTransfersService().scheduleReversibleTransferWithDelaySeconds(
      senderSeed: senderSeed,
      recipientAddress: recipientAddress,
      amount: amount,
      delaySeconds: delaySeconds,
      onStatus: onStatus,
    );
  }

  void updatePendingTransaction(String id, TransactionState newState, {String? blockHash, String? error}) {
    final tx = pendingTransactions.firstWhere(
      (tx) => tx.id == id,
      orElse: () => throw Exception('Pending TX not found'),
    );
    tx.transactionState = newState;
    if (blockHash != null) {
      tx.blockHash = blockHash;
    }
    if (error != null) {
      tx.error = error;
    }
    notifyListeners();
  }

  Timer? _historyPollTimer;

  void _startPollingForHistory() {
    const pollInterval = Duration(seconds: 10);

    if (pendingTransactions.isEmpty) {
      return;
    }
    _historyPollTimer = Timer.periodic(pollInterval, (timer) async {
      try {
        print('polling history');
        await load(quiet: true);
        if (pendingTransactions.isEmpty) {
          print('no more pending tx, ending history polling');
          _historyPollTimer?.cancel();
          _historyPollTimer = null;
        }
      } catch (e) {
        print('error fetching transaction history: $e');
      }
    });
  }
}
