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

  bool get isMultisigCreated => this is MultisigCreatedEvent;

  bool get isPendingMultisigCreation => this is PendingMultisigCreationEvent;

  bool get isMultisigCreation => this is MultisigCreatedEvent || this is PendingMultisigCreationEvent;

  bool get isMultisigProposalCreated => this is MultisigProposalCreatedEvent;

  bool get isMultisigProposalApproved => this is MultisigProposalApprovedEvent;

  bool get isMultisigProposalExecuted => this is MultisigProposalExecutedEvent;

  bool get isMultisigProposalCancelled => this is MultisigProposalCancelledEvent;

  bool get isPendingMultisigProposal => this is PendingMultisigProposalEvent;

  bool get isPendingMultisigExecution => this is PendingMultisigExecutionEvent;

  bool get isPendingMultisigCancellation => this is PendingMultisigCancellationEvent;

  bool get isProposalCreation => this is MultisigProposalCreatedEvent || this is PendingMultisigProposalEvent;
}
