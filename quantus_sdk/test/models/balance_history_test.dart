import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _me = 'qzme';
const _other = 'qzother';

TransferEvent _transfer({
  required String from,
  required String to,
  required int amount,
  int fee = 1,
  required DateTime at,
}) => TransferEvent(
  id: 'tx-${at.millisecondsSinceEpoch}',
  from: from,
  to: to,
  amount: BigInt.from(amount),
  timestamp: at,
  fee: BigInt.from(fee),
  blockNumber: 1,
  blockHash: '0x',
);

ReversibleTransferEvent _reversible({
  required String from,
  required String to,
  required int amount,
  required ReversibleTransferStatus status,
  required DateTime at,
}) => ReversibleTransferEvent(
  id: 'rev-${at.millisecondsSinceEpoch}',
  from: from,
  to: to,
  amount: BigInt.from(amount),
  timestamp: at,
  txId: 'r',
  status: status,
  scheduledAt: at,
  blockNumber: 1,
  blockHash: '0x',
);

void main() {
  final now = DateTime(2026, 10, 16, 12);

  group('deltaFor', () {
    test('outgoing transfers cost amount plus fee, incoming add the amount, self transfers cost the fee', () {
      expect(
        BalanceHistory.deltaFor(_transfer(from: _me, to: _other, amount: 100, fee: 3, at: now), _me),
        BigInt.from(-103),
      );
      expect(
        BalanceHistory.deltaFor(_transfer(from: _other, to: _me, amount: 100, fee: 3, at: now), _me),
        BigInt.from(100),
      );
      expect(
        BalanceHistory.deltaFor(_transfer(from: _me, to: _me, amount: 100, fee: 3, at: now), _me),
        BigInt.from(-3),
      );
      expect(BalanceHistory.deltaFor(_transfer(from: _other, to: _other, amount: 100, at: now), _me), BigInt.zero);
    });

    test('only executed reversible transfers move the balance', () {
      for (final status in [ReversibleTransferStatus.SCHEDULED, ReversibleTransferStatus.CANCELLED]) {
        expect(
          BalanceHistory.deltaFor(_reversible(from: _me, to: _other, amount: 50, status: status, at: now), _me),
          BigInt.zero,
        );
      }
      expect(
        BalanceHistory.deltaFor(
          _reversible(from: _me, to: _other, amount: 50, status: ReversibleTransferStatus.EXECUTED, at: now),
          _me,
        ),
        BigInt.from(-50),
      );
      expect(
        BalanceHistory.deltaFor(
          _reversible(from: _other, to: _me, amount: 50, status: ReversibleTransferStatus.EXECUTED, at: now),
          _me,
        ),
        BigInt.from(50),
      );
    });

    test('mining rewards add to the miner and pending transactions change nothing', () {
      final reward = MinerRewardEvent(
        id: 'r',
        miner: _me,
        reward: BigInt.from(7),
        timestamp: now,
        blockNumber: 1,
        blockHash: '0x',
      );
      expect(BalanceHistory.deltaFor(reward, _me), BigInt.from(7));
      expect(BalanceHistory.deltaFor(reward, _other), BigInt.zero);
      final pending = PendingTransactionEvent(
        tempId: 'p',
        from: _me,
        to: _other,
        amount: BigInt.from(9),
        timestamp: now,
        fee: BigInt.one,
      );
      expect(BalanceHistory.deltaFor(pending, _me), BigInt.zero);
    });
  });

  group('derive', () {
    test('walks back from the current balance through each event', () {
      final history = [
        _transfer(from: _other, to: _me, amount: 40, fee: 1, at: now.subtract(const Duration(days: 1))),
        _transfer(from: _me, to: _other, amount: 10, fee: 2, at: now.subtract(const Duration(days: 3))),
      ];
      final points = BalanceHistory.derive(
        accountId: _me,
        currentBalance: BigInt.from(100),
        newestFirst: history,
        range: BalanceHistoryRange.week,
        now: now,
      );
      expect(points, [
        BalanceHistoryPoint(now.subtract(const Duration(days: 7)), BigInt.from(72)),
        BalanceHistoryPoint(now.subtract(const Duration(days: 3)), BigInt.from(60)),
        BalanceHistoryPoint(now.subtract(const Duration(days: 1)), BigInt.from(100)),
        BalanceHistoryPoint(now, BigInt.from(100)),
      ]);
    });

    test('events before the range set its starting balance and are cut off', () {
      final history = [
        _transfer(from: _other, to: _me, amount: 5, at: now.subtract(const Duration(days: 2))),
        _transfer(from: _other, to: _me, amount: 50, at: now.subtract(const Duration(days: 20))),
        _transfer(from: _other, to: _me, amount: 500, at: now.subtract(const Duration(days: 40))),
      ];
      final points = BalanceHistory.derive(
        accountId: _me,
        currentBalance: BigInt.from(555),
        newestFirst: history,
        range: BalanceHistoryRange.week,
        now: now,
      );
      expect(points.first, BalanceHistoryPoint(now.subtract(const Duration(days: 7)), BigInt.from(550)));
      expect(points.map((p) => p.balance), [BigInt.from(550), BigInt.from(555), BigInt.from(555)]);
    });

    test('the full range starts at the oldest event, or now without history', () {
      final oldest = now.subtract(const Duration(days: 400));
      final points = BalanceHistory.derive(
        accountId: _me,
        currentBalance: BigInt.from(10),
        newestFirst: [_transfer(from: _other, to: _me, amount: 10, at: oldest)],
        range: BalanceHistoryRange.all,
        now: now,
      );
      expect(points, [
        BalanceHistoryPoint(oldest, BigInt.zero),
        BalanceHistoryPoint(oldest, BigInt.from(10)),
        BalanceHistoryPoint(now, BigInt.from(10)),
      ]);

      final empty = BalanceHistory.derive(
        accountId: _me,
        currentBalance: BigInt.from(10),
        newestFirst: const [],
        range: BalanceHistoryRange.all,
        now: now,
      );
      expect(empty, [BalanceHistoryPoint(now, BigInt.from(10))]);
    });
  });
}
