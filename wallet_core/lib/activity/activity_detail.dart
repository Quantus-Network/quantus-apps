import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/explorer_url.dart';
import 'package:wallet_core/utils/transaction_event_extension.dart';

/// Where a transaction stands.
enum ActivityStatus {
  /// Broadcast, or about to be, and not yet seen settled.
  inProcess,

  /// A reversible transfer waiting for its time to run.
  scheduled,

  completed;

  String label(AppLocalizations l10n) => switch (this) {
    inProcess => l10n.activityDetailStatusInProcess,
    scheduled => l10n.activityDetailStatusScheduled,
    completed => l10n.activityDetailStatusCompleted,
  };
}

/// What a transaction's own page says of it, whichever app draws it: what it
/// is, where it stands, whether the money went out, and where the block
/// explorer shows it.
@immutable
class ActivityDetail {
  const ActivityDetail({required this.title, required this.status, required this.isSend, required this.explorerUrl});

  final String title;
  final ActivityStatus status;

  /// Whether the money went out of the account, so its amount is an outflow.
  final bool isSend;

  /// The explorer's page of it, or null when it has none yet. An app offers
  /// it only once the transaction is no longer [ActivityStatus.inProcess].
  final String? explorerUrl;

  @override
  bool operator ==(Object other) =>
      other is ActivityDetail &&
      other.title == title &&
      other.status == status &&
      other.isSend == isSend &&
      other.explorerUrl == explorerUrl;

  @override
  int get hashCode => Object.hash(title, status, isSend, explorerUrl);

  @override
  String toString() => 'ActivityDetail($title, $status, isSend: $isSend, $explorerUrl)';
}

/// What [tx]'s page says of it to the account [accountId]; with [isPrivate],
/// to an encrypted account, whose transfers are private.
ActivityDetail activityDetailOf(
  TransactionEvent tx, {
  required String accountId,
  required AppLocalizations l10n,
  bool isPrivate = false,
}) {
  final isSend = isActivitySend(tx, accountId: accountId);
  return ActivityDetail(
    title: _title(tx, isSend: isSend, isPrivate: isPrivate, l10n: l10n),
    status: _isInProcess(tx)
        ? ActivityStatus.inProcess
        : tx.isReversibleScheduled
        ? ActivityStatus.scheduled
        : ActivityStatus.completed,
    isSend: isSend,
    explorerUrl: _explorerUrl(tx),
  );
}

/// Whether [tx] took money out of the account [accountId]. A multisig's
/// proposals are told as sends: what they move leaves it. A multisig's
/// creation is a send only for its creator, who paid for it.
bool isActivitySend(TransactionEvent tx, {required String accountId}) =>
    switch (tx) {
      PendingMultisigProposalEvent() ||
      PendingMultisigExecutionEvent() ||
      PendingMultisigCancellationEvent() ||
      MultisigProposalCreatedEvent() ||
      MultisigProposalApprovedEvent() ||
      MultisigProposalExecutedEvent() ||
      MultisigProposalCancelledEvent() ||
      MultisigProposalEvent() => true,
      _ => false,
    } ||
    tx.from == accountId;

bool _isInProcess(TransactionEvent tx) => switch (tx) {
  PendingTransactionEvent() ||
  PendingMultisigCreationEvent() ||
  PendingMultisigProposalEvent() ||
  PendingMultisigExecutionEvent() ||
  PendingMultisigCancellationEvent() => true,
  _ => false,
};

String _title(TransactionEvent tx, {required bool isSend, required bool isPrivate, required AppLocalizations l10n}) {
  switch (tx) {
    case PendingMultisigProposalEvent():
      return l10n.activityDetailTitleProposing;
    case PendingMultisigExecutionEvent():
      return l10n.activityDetailTitleExecuting;
    case PendingMultisigCancellationEvent():
      return l10n.activityDetailTitleCancelling;
    case MultisigProposalCreatedEvent():
      return l10n.activityDetailTitleProposalCreated;
    case MultisigProposalApprovedEvent():
      return l10n.activityDetailTitleProposalApproved;
    case MultisigProposalExecutedEvent():
      return l10n.activityDetailTitleProposalExecuted;
    case MultisigProposalCancelledEvent():
      return l10n.activityDetailTitleProposalCancelled;
    case PendingMultisigCreationEvent():
      return l10n.activityDetailTitleMultisigCreating;
    case MultisigCreatedEvent():
      return l10n.activityDetailTitleMultisigCreated;
    case PendingTransactionEvent():
      return isPrivate ? l10n.activityDetailTitlePrivatelySending : l10n.activityDetailTitleSending;
  }
  if (tx.isReversibleScheduled) {
    if (isSend) return l10n.activityDetailTitleScheduled;
    return isPrivate ? l10n.activityDetailTitlePrivatelyReceiving : l10n.activityDetailTitleReceiving;
  }
  if (isSend) return isPrivate ? l10n.activityDetailTitlePrivateSent : l10n.activityDetailTitleSent;
  return isPrivate ? l10n.activityDetailTitlePrivateReceived : l10n.activityDetailTitleReceived;
}

String? _explorerUrl(TransactionEvent tx) {
  final String kind;
  if (tx.isMultisigProposalExecuted) {
    kind = 'multisig-proposal-executed';
  } else if (tx.isMultisigProposalCancelled) {
    kind = 'multisig-proposal-cancelled';
  } else if (tx.isMultisigProposalApproved) {
    kind = 'multisig-signer-approved';
  } else if (tx.isProposalCreation) {
    kind = 'multisig-proposal-created';
  } else if (tx.isMultisigCreated) {
    kind = 'multisig-created';
  } else if (tx.isMinerReward) {
    kind = 'miner-rewards';
  } else if (tx.isWormhole) {
    kind = 'transactions/wormhole';
  } else if (tx.isReversibleScheduled) {
    kind = 'transactions/scheduled-reversible';
  } else if (tx.isReversibleExecuted) {
    kind = 'transactions/executed-reversible';
  } else if (tx.isReversibleCancelled) {
    kind = 'transactions/cancelled-reversible';
  } else {
    kind = 'transactions';
  }

  final hash = tx.extrinsicHash;
  if (tx is ReversibleTransferEvent) return explorerUrl('$kind/${tx.txId}');
  if (hash != null) return explorerUrl('$kind/$hash');
  if (tx.isMinerReward && tx.blockHash != null) return explorerUrl('$kind/${tx.blockHash}');
  return null;
}
