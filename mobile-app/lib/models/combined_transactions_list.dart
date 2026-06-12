import 'package:quantus_sdk/quantus_sdk.dart';

class CombinedTransactionsList {
  final Set<String> pendingCancellationIds;
  final List<PendingTransactionEvent> pendingTransactions;
  final List<PendingMultisigCreationEvent> pendingMultisigCreations;
  final List<PendingMultisigProposalEvent> pendingMultisigProposals;
  final List<PendingMultisigExecutionEvent> pendingMultisigExecutions;
  final List<PendingMultisigCancellationEvent> pendingMultisigCancellations;
  final List<ReversibleTransferEvent> scheduledReversibleTransfers;
  final List<TransactionEvent> otherTransfers;

  CombinedTransactionsList({
    required this.pendingCancellationIds,
    required this.pendingTransactions,
    required this.pendingMultisigCreations,
    required this.pendingMultisigProposals,
    required this.pendingMultisigExecutions,
    required this.pendingMultisigCancellations,
    required this.scheduledReversibleTransfers,
    required this.otherTransfers,
  });

  CombinedTransactionsList copyWith({
    Set<String>? pendingCancellationIds,
    List<PendingTransactionEvent>? pendingTransactions,
    List<PendingMultisigCreationEvent>? pendingMultisigCreations,
    List<PendingMultisigProposalEvent>? pendingMultisigProposals,
    List<PendingMultisigExecutionEvent>? pendingMultisigExecutions,
    List<PendingMultisigCancellationEvent>? pendingMultisigCancellations,
    List<ReversibleTransferEvent>? scheduledReversibleTransfers,
    List<TransactionEvent>? otherTransfers,
  }) {
    return CombinedTransactionsList(
      pendingCancellationIds: pendingCancellationIds ?? this.pendingCancellationIds,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      pendingMultisigCreations: pendingMultisigCreations ?? this.pendingMultisigCreations,
      pendingMultisigProposals: pendingMultisigProposals ?? this.pendingMultisigProposals,
      pendingMultisigExecutions: pendingMultisigExecutions ?? this.pendingMultisigExecutions,
      pendingMultisigCancellations: pendingMultisigCancellations ?? this.pendingMultisigCancellations,
      scheduledReversibleTransfers: scheduledReversibleTransfers ?? this.scheduledReversibleTransfers,
      otherTransfers: otherTransfers ?? this.otherTransfers,
    );
  }

  static CombinedTransactionsList get empty => CombinedTransactionsList(
    pendingCancellationIds: <String>{},
    pendingTransactions: [],
    pendingMultisigCreations: [],
    pendingMultisigProposals: [],
    pendingMultisigExecutions: [],
    pendingMultisigCancellations: [],
    scheduledReversibleTransfers: [],
    otherTransfers: [],
  );
}
