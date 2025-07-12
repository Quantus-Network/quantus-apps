import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'dart:isolate'; // For isolate spawning

enum TxState { sent, includedInBlock, includedInHistory, failed }

class ManagedTransaction {
  TransactionEvent event;
  TxState state;

  ManagedTransaction(this.event, {this.state = TxState.sent});
}

class WalletStateManager extends ChangeNotifier {
  static WalletStateManager? _instance;
  factory WalletStateManager({
    SettingsService? settingsService,
    SubstrateService? substrateService,
    ChainHistoryService? chainHistoryService,
  }) {
    _instance ??= WalletStateManager._internal(
      settingsService ?? SettingsService(),
      substrateService ?? SubstrateService(),
      chainHistoryService ?? ChainHistoryService(),
    );
    return _instance!;
  }

  final SettingsService _settingsService;
  final SubstrateService _substrateService;
  final ChainHistoryService _chainHistoryService;

  WalletStateManager._internal(this._settingsService, this._substrateService, this._chainHistoryService);

  BigInt _currentBalance = BigInt.zero;
  List<ManagedTransaction> _transactions = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  BigInt get currentBalance => _currentBalance;
  List<TransactionEvent> get transactions => _transactions.map((mt) => mt.event).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<TransactionEvent> get scheduledReversibleTxs => _transactions
      .where(
        (mt) =>
            mt.event is ReversibleTransferEvent &&
            (mt.event as ReversibleTransferEvent).status == ReversibleTransferStatus.SCHEDULED,
      )
      .map((mt) => mt.event)
      .toList();

  List<TransactionEvent> get otherTxs => _transactions
      .where(
        (mt) =>
            !(mt.event is ReversibleTransferEvent &&
                (mt.event as ReversibleTransferEvent).status == ReversibleTransferStatus.SCHEDULED),
      )
      .map((mt) => mt.event)
      .toList();

  void updateBalance(BigInt newBalance) {
    _currentBalance = newBalance;
    notifyListeners();
  }

  void addTransactions(SortedTransactionsList newTxs) {
    _transactions.addAll(newTxs.combined.map((tx) => ManagedTransaction(tx, state: TxState.includedInHistory)));
    _transactions.sort((a, b) => b.event.timestamp.compareTo(a.event.timestamp));
    notifyListeners();
  }

  Future<void> addPendingSend({required BigInt amount, required String to, bool isReversible = false}) async {
    final String tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final pendingEvent = isReversible
        ? ReversibleTransferEvent(
            id: tempId,
            from: 'currentWallet', // Replace with actual
            to: to,
            amount: amount,
            timestamp: DateTime.now(),
            txId: 'pending',
            status: ReversibleTransferStatus.SCHEDULED,
            scheduledAt: DateTime.now().add(const Duration(hours: 1)),
            extrinsicHash: null,
            blockNumber: 0,
          )
        : TransferEvent(
            id: tempId,
            from: 'currentWallet',
            to: to,
            amount: amount,
            timestamp: DateTime.now(),
            fee: BigInt.zero,
            extrinsicHash: null,
            blockNumber: 0,
          );
    _transactions.insert(0, ManagedTransaction(pendingEvent));
    _currentBalance -= amount;
    notifyListeners();

    // Start background monitoring (simulate for now)
    compute(_monitorTx, {'txId': pendingEvent.id}).then((confirmedEvent) {
      final index = _transactions.indexWhere((mt) => mt.event.id == pendingEvent.id);
      if (index != -1) {
        _transactions[index].event = confirmedEvent ?? pendingEvent;
        _transactions[index].state = TxState.includedInHistory;
        notifyListeners();
      }
    });
  }

  static Future<TransactionEvent?> _monitorTx(Map<String, dynamic> params) async {
    final String txId = params['txId'] ?? params['pendingEvent']?.id ?? '';
    if (txId.isEmpty) return null;
    // Simulate background work: poll Subsquid/chain for confirmation
    await Future.delayed(const Duration(seconds: 10)); // Replace with real polling
    // For demo, return a confirmed event or null on failure
    return null; // Simulate failure; implement real logic
  }

  Future<void> _monitorPendingTx(TransactionEvent pendingEvent) async {
    final accountId = await _settingsService.getAccountId();
    if (accountId == null) {
      debugPrint('Account ID not available for monitoring pending transaction.');
      return;
    }
    await compute<Map<String, dynamic>, TransactionEvent?>(_monitorTx, {
      'pendingEvent': pendingEvent,
      'accountId': accountId,
    });
  }

  static Future<BigInt> _fetchBalance(String accountId) async {
    return SubstrateService().queryBalance(accountId);
  }

  static Future<SortedTransactionsList> _fetchHistory(Map<String, dynamic> params) async {
    return ChainHistoryService().fetchAllTransactionTypes(
      accountId: params['id'] as String,
      limit: params['limit'] as int,
      offset: params['offset'] as int,
    );
  }

  Future<void> refresh() async {
    _offset = 0;
    _hasMore = true;
    _transactions.clear();
    await loadInitialData();
  }

  Future<void> loadInitialData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final accountId = await _settingsService.getAccountId();
    if (accountId == null) {
      _error = 'No account ID';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final balance = await _substrateService.queryBalance(accountId);
      updateBalance(balance);

      final history = await _chainHistoryService.fetchAllTransactionTypes(accountId: accountId, limit: 20, offset: 0);
      addTransactions(history);
      _hasMore = history.combined.length == 20;
      _offset = history.combined.length;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreTransactions() async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    final accountId = await _settingsService.getAccountId();
    if (accountId == null) return;

    try {
      final history = await _chainHistoryService.fetchAllTransactionTypes(
        accountId: accountId,
        limit: 20,
        offset: _offset,
      );
      addTransactions(history);
      _hasMore = history.combined.length == 20;
      _offset += history.combined.length;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> performSend({
    required BigInt amount,
    required String recipientAddress,
    required int reversibleTimeSeconds,
  }) async {
    final senderSeed = await _settingsService.getMnemonic();
    if (senderSeed == null) {
      throw Exception('No sender seed available');
    }

    // Optimistic add
    addPendingSend(amount: amount, to: recipientAddress, isReversible: reversibleTimeSeconds > 0);

    // Spawn isolate for actual send
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_sendIsolateEntry, [
      receivePort.sendPort,
      senderSeed,
      recipientAddress,
      amount,
      reversibleTimeSeconds,
    ]);

    final completer = Completer<bool>();
    receivePort.listen((message) {
      if (message is bool) {
        final index = _transactions.indexWhere((mt) => mt.event.id.startsWith('pending_'));
        if (index != -1) {
          if (message) {
            // Start monitoring for on-chain confirmation
            _monitorPendingTx(_transactions[index].event);
          } else {
            _transactions[index].state = TxState.failed;
          }
          notifyListeners();
        }
        completer.complete(message);
        isolate.kill();
        receivePort.close();
      }
    });

    return completer.future;
  }

  static void _sendIsolateEntry(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final String senderSeed = args[1];
    final String recipientAddress = args[2];
    final BigInt amount = args[3];
    final int reversibleTimeSeconds = args[4];

    await QuantusSdk.init();
    await SubstrateService().initialize();

    try {
      if (reversibleTimeSeconds <= 0) {
        await BalancesService().balanceTransfer(senderSeed, recipientAddress, amount);
      } else {
        await ReversibleTransfersService().scheduleReversibleTransferWithDelaySeconds(
          senderSeed: senderSeed,
          recipientAddress: recipientAddress,
          amount: amount,
          delaySeconds: reversibleTimeSeconds,
        );
      }
      sendPort.send(true);
    } catch (e) {
      debugPrint('Send failed in background: $e');
      sendPort.send(false);
    }
  }
}
