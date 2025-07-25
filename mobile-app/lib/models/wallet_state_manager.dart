import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pending_transfer_event.dart';
import 'package:resonance_network_wallet/models/wallet_data.dart';

class WalletStateManager with ChangeNotifier {
  static const fastPollInterval = Duration(seconds: 10);
  static const slowPollInterval = Duration(seconds: 60);

  final SettingsService _settingsService;
  final ChainHistoryService _chainHistoryService;
  final SubstrateService _substrateService;

  // --- Wallet Data State ---
  WalletData? _walletData;
  WalletData? get walletData => _walletData;

  bool get isWalletLoading => _isWalletLoading;
  bool _isWalletLoading = false;

  String? get walletError => _walletError;
  String? _walletError;

  // --- Transaction History State ---
  SortedTransactionsList? get txHistory => _txHistory;
  SortedTransactionsList? _txHistory;

  bool get isTxHistoryLoading => _isTxHistoryLoading;
  bool _isTxHistoryLoading = false;

  String? get txHistoryError => _txHistoryError;
  String? _txHistoryError;

  // --- Pending Transactions State ---
  final List<PendingTransactionEvent> _pendingTransactions = [];

  Timer? _pollingTimer;

  WalletStateManager(
    this._chainHistoryService,
    this._settingsService,
    this._substrateService,
  ) {
    _resetPollingTimer();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    super.dispose();
  }

  Future<void> _updateTransactionHistory({bool quiet = false}) async {
    if (!quiet) {
      _isTxHistoryLoading = true;
      _txHistoryError = null;
    }

    try {
      final account = await _settingsService.getActiveAccount();
      _txHistory = await _chainHistoryService.fetchAllTransactionTypes(
        accountId: account.accountId,
        limit: 20,
        offset: 0,
      );
    } catch (e) {
      print('Load tx history error: $e');
      if (!quiet) {
        _txHistoryError = e.toString();
      }
    } finally {
      if (!quiet) {
        _isTxHistoryLoading = false;
      }
    }
  }

  Future<void> _updateBalance({bool quiet = false}) async {
    const Duration networkTimeout = Duration(seconds: 15);
    if (!quiet) {
      _isWalletLoading = true;
      _walletError = null;
    }

    try {
      final account = await _settingsService.getActiveAccount();
      final balance = await _substrateService
          .queryBalance(account.accountId)
          .timeout(networkTimeout);
      _walletData = WalletData(account: account, balance: balance);
    } catch (e) {
      print('Load balance error: $e');
      if (!quiet) {
        _walletError = e.toString();
      }
    } finally {
      if (!quiet) {
        _isWalletLoading = false;
      }
    }
  }

  BigInt get estimatedBalance {
    if (_walletData == null) return BigInt.zero;
    BigInt base = _walletData!.balance;
    for (var tx in _pendingTransactions) {
      if (tx.transactionState != TransactionState.inHistory &&
          tx.transactionState != TransactionState.failed) {
        final isSend = tx.from == _walletData!.account.accountId;
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
    final fetched = _txHistory?.combined ?? [];
    final all = [...fetched, ..._pendingTransactions];
    all.sort((a, b) {
      final tsA = a.timestamp;
      final tsB = b.timestamp;
      return tsB.compareTo(tsA);
    });
    return all;
  }

  Future<void> load({bool quiet = false}) async {
    await Future.wait([
      _updateTransactionHistory(quiet: quiet),
      _updateBalance(quiet: quiet),
    ]);
    updatePendingTransactions();
    notifyListeners();
  }

  Future<void> switchAccount(Account account) async {
    await _settingsService.setActiveAccount(account);
    await load();
  }

  Future<void> refreshTransactions({bool quiet = false}) async {
    await _updateTransactionHistory(quiet: quiet);
    updatePendingTransactions();
    notifyListeners();
  }

  // Update pending transactions - see if any have been resolved in the history
  // list, and remove them accordingly as they are coming in with chain history.
  bool updatePendingTransactions() {
    bool updated = false;
    var transferList = _txHistory?.combined ?? [];
    List<PendingTransactionEvent> toRemove = [];
    for (var pending in _pendingTransactions) {
      if (pending.transactionState == TransactionState.failed) {
        toRemove.add(pending);
        updated = true;
      }
      if (pending.blockHash != null) {
        print('pending ${pending.amount} block hash: ${pending.blockHash}');

        for (var transfer in transferList) {
          print(
            'checking trasfer ${transfer.amount} with block hash: '
            '${transfer.blockHash}',
          );
          if (transfer.blockHash == pending.blockHash) {
            print('found item block hash - removing');
            toRemove.add(pending);
            updated = true;
          }
        }
      }
    }

    if (toRemove.isNotEmpty) {
      _pendingTransactions.removeWhere((tx) => toRemove.contains(tx));
    }
    if (updated) {
      notifyListeners();
    }
    return updated;
  }

  Future<void> loadMoreTransactions({
    required String accountId,
    required int limit,
    required int offset,
  }) async {
    final result = await _chainHistoryService.fetchAllTransactionTypes(
      accountId: accountId,
      limit: limit,
      offset: offset,
    );
    if (_txHistory == null) {
      _txHistory = result;
    } else {
      _txHistory!.otherTransfers.addAll(result.otherTransfers);
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
    _pendingTransactions.add(pending);
    notifyListeners();
  }

  void _resetPollingTimer() {
    _pollingTimer?.cancel();

    final pollInterval = _pendingTransactions.isNotEmpty
        ? fastPollInterval
        : slowPollInterval;

    print('polling at $pollInterval');

    _pollingTimer = Timer(pollInterval, () async {
      try {
        await load(quiet: true);
      } catch (e) {
        print('error polling for history: $e');
      } finally {
        _resetPollingTimer();
      }
    });
  }

  String _senderAddressFromAccount(Account account) {
    return account.accountId;
  }

  Future<String> balanceTransfer(
    Account account,
    String targetAddress,
    BigInt amount,
    BigInt feeEstimate, {
    int maxRetries = 3,
  }) async {
    final pending = createPendingTransaction(
      from: _senderAddressFromAccount(account),
      to: targetAddress,
      amount: amount,
      fee: feeEstimate,
    );

    await _submitAndTrackTransaction(
      submission: (onStatus) => BalancesService().balanceTransfer(
        account,
        targetAddress,
        amount,
        onStatus,
      ),
      pendingTx: pending,
      maxRetries: maxRetries,
    );

    return pending.id;
  }

  Future<void> scheduleReversibleTransferWithDelaySeconds({
    required Account account,
    required String recipientAddress,
    required BigInt amount,
    required int delaySeconds,
    required BigInt feeEstimate,
    int maxRetries = 3,
  }) async {
    final pending = createPendingTransaction(
      from: _senderAddressFromAccount(account),
      to: recipientAddress,
      amount: amount,
      fee: feeEstimate,
      isReversible: true,
    );

    await _submitAndTrackTransaction(
      submission: (onStatus) => ReversibleTransfersService()
          .scheduleReversibleTransferWithDelaySeconds(
            account: account,
            recipientAddress: recipientAddress,
            amount: amount,
            delaySeconds: delaySeconds,
            onStatus: onStatus,
          ),
      pendingTx: pending,
      maxRetries: maxRetries,
    );
  }

  void updatePendingTransaction(
    String id,
    TransactionState newState, {
    String? blockHash,
    String? error,
  }) {
    final tx = _pendingTransactions.firstWhere(
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

  void refreshActiveAccount() {
    load(); // async!
  }

  Future<void> _submitAndTrackTransaction({
    required Future<StreamSubscription<ExtrinsicStatus>> Function(
      void Function(ExtrinsicStatus) onStatus,
    )
    submission,
    required PendingTransactionEvent pendingTx,
    int maxRetries = 3,
  }) async {
    addPendingTransaction(pendingTx);
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
          // This status is not expected here because we should unsubscribe
          // after 'inBlock' to let the history poller take over.
          newState = TransactionState.inBlock;
          break;
        default:
          newState = TransactionState.failed;
          pendingTx.error = 'Unknown status: ${status.type}';
      }
      updatePendingTransaction(pendingTx.id, newState, blockHash: hash);

      if (newState == TransactionState.inBlock && hash != null) {
        _resetPollingTimer();
        subscription?.cancel();
      }
    }

    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        subscription = await submission(onStatus);
        return; // Success, exit the retry loop.
      } catch (e, stackTrace) {
        attempts++;
        if (attempts >= maxRetries) {
          updatePendingTransaction(
            pendingTx.id,
            TransactionState.failed,
            error: e.toString(),
          );
          print('Failed to submit transaction after $maxRetries attempts: $e');
          print('Stack trace: $stackTrace');
          rethrow;
        } else {
          print('Transaction attempt $attempts failed: $e. Retrying...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }
}
