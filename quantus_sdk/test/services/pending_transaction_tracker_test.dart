import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class _FakeHistory implements ChainHistoryService {
  TransactionEvent? answer;
  Object? error;
  int hashSearches = 0;
  int fallbackSearches = 0;

  @override
  Future<TransactionEvent?> searchByExtrinsicHash({required String extrinsicHash, required bool isReversible}) async {
    hashSearches++;
    if (error != null) throw error!;
    return answer;
  }

  @override
  Future<TransactionEvent?> searchForPendingTransaction({
    required String from,
    required String to,
    required BigInt amount,
    required bool isReversible,
    required int blockHeightAfter,
  }) async {
    fallbackSearches++;
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

PendingTransactionEvent _pending({String? hash, int blockNumber = 10}) => PendingTransactionEvent(
  tempId: 'pending_1',
  from: 'from',
  to: 'to',
  amount: BigInt.one,
  timestamp: DateTime(2026),
  fee: BigInt.zero,
  blockNumber: blockNumber,
  extrinsicHash: hash,
);

TransferEvent _found() => TransferEvent(
  id: 'tx',
  from: 'from',
  to: 'to',
  amount: BigInt.one,
  timestamp: DateTime(2026),
  blockNumber: 11,
  blockHash: '0xabc',
  extrinsicHash: '0x01',
  fee: BigInt.zero,
);

void main() {
  test('resolves with the indexed event, searching by hash first', () {
    fakeAsync((async) {
      final history = _FakeHistory();
      final tracker = PendingTransactionTracker(history: history, interval: const Duration(seconds: 5));
      TransactionEvent? result;
      tracker.track(_pending(hash: '0x01')).then((event) => result = event);

      async.elapse(const Duration(seconds: 6));
      expect(result, isNull);
      expect(history.hashSearches, 2);
      expect(history.fallbackSearches, 0);

      history.answer = _found();
      async.elapse(const Duration(seconds: 5));
      expect(result, isNotNull);
      async.elapse(const Duration(minutes: 1));
      expect(history.hashSearches, 3);
    });
  });

  test('falls back to matching by sender, recipient, amount and block', () {
    fakeAsync((async) {
      final history = _FakeHistory()..answer = _found();
      final tracker = PendingTransactionTracker(history: history);
      TransactionEvent? result;
      tracker.track(_pending()).then((event) => result = event);
      async.flushMicrotasks();
      expect(result, isNotNull);
      expect(history.fallbackSearches, 1);
    });
  });

  test('refuses a transaction it cannot identify', () {
    final tracker = PendingTransactionTracker(history: _FakeHistory());
    expect(() => tracker.track(_pending(blockNumber: 0)), throwsArgumentError);
  });

  test('resolves null after the timeout and keeps searching through errors', () {
    fakeAsync((async) {
      final history = _FakeHistory()..error = Exception('indexer down');
      final tracker = PendingTransactionTracker(
        history: history,
        interval: const Duration(seconds: 5),
        timeout: const Duration(seconds: 20),
      );
      var completed = false;
      TransactionEvent? result = _found();
      tracker.track(_pending(hash: '0x01')).then((event) {
        completed = true;
        result = event;
      });

      async.elapse(const Duration(seconds: 19));
      expect(completed, isFalse);
      expect(history.hashSearches, 4);
      async.elapse(const Duration(seconds: 1));
      expect(completed, isTrue);
      expect(result, isNull);
    });
  });

  test('cancel and re-track drop the earlier future', () {
    fakeAsync((async) {
      final history = _FakeHistory();
      final tracker = PendingTransactionTracker(history: history, interval: const Duration(seconds: 5));
      var firstCompleted = false;
      tracker.track(_pending(hash: '0x01')).then((_) => firstCompleted = true);
      tracker.cancel('pending_1');
      async.elapse(const Duration(minutes: 10));
      expect(firstCompleted, isFalse);
      expect(history.hashSearches, 1);

      TransactionEvent? second;
      tracker.track(_pending(hash: '0x01')).then((event) => second = event);
      var replaced = false;
      tracker.track(_pending(hash: '0x01')).then((_) => replaced = true);
      history.answer = _found();
      async.elapse(const Duration(seconds: 5));
      expect(second, isNull);
      expect(replaced, isTrue);
      tracker.dispose();
    });
  });
}
