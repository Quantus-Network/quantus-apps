import 'package:quantus_sdk/quantus_sdk.dart';

extension TransactionEventExtension on TransactionEvent {
  bool get isReversibleScheduled =>
      this is ReversibleTransferEvent && (this as ReversibleTransferEvent).status == ReversibleTransferStatus.SCHEDULED;

  bool get isReversibleExecuted =>
      this is ReversibleTransferEvent && (this as ReversibleTransferEvent).status == ReversibleTransferStatus.EXECUTED;

  bool get isReversibleCancelled =>
      this is ReversibleTransferEvent && (this as ReversibleTransferEvent).status == ReversibleTransferStatus.CANCELLED;

  bool get isFailed =>
      this is PendingTransactionEvent && (this as PendingTransactionEvent).transactionState == TransactionState.failed;

  bool get isPendingOrScheduled => this is PendingTransactionEvent || isReversibleScheduled;

  // this is guaranteed to be positive
  Duration get timeRemaining =>
      this is ReversibleTransferEvent ? (this as ReversibleTransferEvent).remainingTime : Duration.zero;

  bool get isMinerReward => this is MinerRewardEvent;
}
