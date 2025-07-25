import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pending_transfer_event.dart';

extension TransactionEventExtension on TransactionEvent {
  bool get isReversibleScheduled =>
      this is ReversibleTransferEvent &&
      (this as ReversibleTransferEvent).status ==
          ReversibleTransferStatus.SCHEDULED;

  bool get isReversibleExecuted =>
      this is ReversibleTransferEvent &&
      (this as ReversibleTransferEvent).status ==
          ReversibleTransferStatus.EXECUTED;

  bool get isReversibleCancelled =>
      this is ReversibleTransferEvent &&
      (this as ReversibleTransferEvent).status ==
          ReversibleTransferStatus.CANCELLED;

  bool get isFailed =>
      this is PendingTransactionEvent &&
      (this as PendingTransactionEvent).transactionState ==
          TransactionState.failed;

  // this is guaranteed to be positive
  Duration get timeRemaining => this is ReversibleTransferEvent
      ? (this as ReversibleTransferEvent).remainingTime
      : Duration.zero;
}
