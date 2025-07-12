import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
    final pendingEvent = isReversible
        ? ReversibleTransferEvent(
            id: 'pending_${Random().nextInt(100000)}',
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
            id: 'pending_${Random().nextInt(100000)}',
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
    compute(_monitorTx, pendingEvent.id).then((confirmedEvent) {
      final index = _transactions.indexWhere((mt) => mt.event.id == pendingEvent.id);
      if (index != -1) {
        _transactions[index].event = confirmedEvent ?? pendingEvent;
        _transactions[index].state = TxState.includedInHistory;
        notifyListeners();
      }
    });
  }

  static Future<TransactionEvent?> _monitorTx(String txId) async {
    // Simulate background work: poll Subsquid/chain for confirmation
    await Future.delayed(const Duration(seconds: 10)); // Replace with real polling
    // For demo, return a confirmed event or null on failure
    return null; // Simulate failure; implement real logic
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
}
