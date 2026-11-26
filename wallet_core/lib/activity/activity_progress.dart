import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/transaction_event_extension.dart';

/// Whether [tx] is still in progress: a send on its way that has not failed, a
/// transfer scheduled to run, or a multisig step on its way to the chain.
bool isActivityInProgress(TransactionEvent tx) => switch (tx) {
  PendingTransactionEvent() => !tx.isFailed,
  PendingMultisigCreationEvent() ||
  PendingMultisigProposalEvent() ||
  PendingMultisigApprovalEvent() ||
  PendingMultisigExecutionEvent() ||
  PendingMultisigCancellationEvent() => true,
  _ => tx.isReversibleScheduled,
};

/// [activity] parted into what is still in progress and what is settled,
/// each in the order given.
({List<TransactionEvent> inProgress, List<TransactionEvent> settled}) partActivityByProgress(
  List<TransactionEvent> activity,
) => (
  inProgress: activity.where(isActivityInProgress).toList(),
  settled: activity.where((tx) => !isActivityInProgress(tx)).toList(),
);
