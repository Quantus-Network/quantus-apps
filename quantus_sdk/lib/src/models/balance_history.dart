import 'package:quantus_sdk/src/models/miner_reward_event.dart';
import 'package:quantus_sdk/src/models/pending_transfer_event.dart';
import 'package:quantus_sdk/src/models/reversible_transfer_status.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

enum BalanceHistoryRange {
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  quarter(Duration(days: 90)),
  year(Duration(days: 365)),
  all(null);

  final Duration? span;

  const BalanceHistoryRange(this.span);
}

class BalanceHistoryPoint {
  final DateTime at;
  final BigInt balance;

  const BalanceHistoryPoint(this.at, this.balance);

  @override
  bool operator ==(Object other) => other is BalanceHistoryPoint && other.at == at && other.balance == balance;

  @override
  int get hashCode => Object.hash(at, balance);

  @override
  String toString() => 'BalanceHistoryPoint($at, $balance)';
}

/// A balance-over-time series reconstructed from indexed history. Walks back
/// from the current balance through each event's effect on it. Fees on
/// executed reversible transfers, locked funds of scheduled ones, multisig
/// deposits and existential-deposit reaping are not indexed, so the series is
/// an approximation.
abstract final class BalanceHistory {
  /// How [event] changed [accountId]'s free balance when it was indexed.
  static BigInt deltaFor(TransactionEvent event, String accountId) {
    final incoming = event.to == accountId;
    final outgoing = event.from == accountId;
    return switch (event) {
      PendingTransactionEvent() => BigInt.zero,
      MinerRewardEvent() => incoming ? event.amount : BigInt.zero,
      TransferEvent() when outgoing && incoming => -event.fee,
      TransferEvent() when outgoing => -(event.amount + event.fee),
      TransferEvent() when incoming => event.amount,
      ReversibleTransferEvent() when event.status != ReversibleTransferStatus.EXECUTED => BigInt.zero,
      ReversibleTransferEvent() when outgoing && incoming => BigInt.zero,
      ReversibleTransferEvent() when outgoing => -event.amount,
      ReversibleTransferEvent() when incoming => event.amount,
      _ => BigInt.zero,
    };
  }

  /// Points from the start of [range] to [now], oldest first. [newestFirst]
  /// is the indexed history, newest event first, reaching back at least to
  /// the range start when the history has it.
  static List<BalanceHistoryPoint> derive({
    required String accountId,
    required BigInt currentBalance,
    required List<TransactionEvent> newestFirst,
    required BalanceHistoryRange range,
    required DateTime now,
  }) {
    if (newestFirst.isEmpty) return [BalanceHistoryPoint(now, currentBalance)];
    final span = range.span;
    final start = span == null ? newestFirst.last.timestamp : now.subtract(span);
    var balance = currentBalance;
    final points = <BalanceHistoryPoint>[BalanceHistoryPoint(now, balance)];
    for (final event in newestFirst) {
      if (event.timestamp.isAfter(now)) continue;
      if (event.timestamp.isBefore(start)) break;
      points.add(BalanceHistoryPoint(event.timestamp, balance));
      balance -= deltaFor(event, accountId);
    }
    points.add(BalanceHistoryPoint(start, balance));
    return points.reversed.toList();
  }
}
