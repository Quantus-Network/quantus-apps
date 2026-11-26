import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/transaction_event_extension.dart';

/// How a row of the activity stands out: not at all once settled, or, while
/// still under way, as money arriving or as money leaving.
enum ActivityHighlight { none, arriving, leaving }

/// What a row's picture stands for: the money's direction, a multisig
/// proposal, or a multisig being made.
enum ActivityIcon { direction, proposal, multisig }

/// Who or what is on the other side of a row.
sealed class ActivityCounterparty {
  const ActivityCounterparty();

  /// The words before it: "To", "From", "Multisig", or none.
  String prefix(AppLocalizations l10n);
}

/// An account, by its whole address: the one paid when [isRecipient], else
/// the one who paid. Each app shortens it, or not, as it shows addresses.
final class ActivityAccount extends ActivityCounterparty {
  const ActivityAccount(this.address, {required this.isRecipient});

  final String address;
  final bool isRecipient;

  @override
  String prefix(AppLocalizations l10n) => isRecipient ? l10n.activityTxTo : l10n.activityTxFrom;

  @override
  bool operator ==(Object other) =>
      other is ActivityAccount && other.address == address && other.isRecipient == isRecipient;

  @override
  int get hashCode => Object.hash(address, isRecipient);

  @override
  String toString() => 'ActivityAccount($address, isRecipient: $isRecipient)';
}

/// The multisig a row is about, by its whole address.
final class ActivityMultisig extends ActivityCounterparty {
  const ActivityMultisig(this.address);

  final String address;

  @override
  String prefix(AppLocalizations l10n) => l10n.activityTxMultisigLabel;

  @override
  bool operator ==(Object other) => other is ActivityMultisig && other.address == address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'ActivityMultisig($address)';
}

/// What has no address to show: it is named in words ([name]).
sealed class ActivityUnnamedCounterparty extends ActivityCounterparty {
  const ActivityUnnamedCounterparty();

  String name(AppLocalizations l10n);
}

/// The sender of a private receipt, which the chain does not reveal.
final class ActivityEncryptedSender extends ActivityUnnamedCounterparty {
  const ActivityEncryptedSender();

  @override
  String prefix(AppLocalizations l10n) => l10n.activityTxFrom;

  @override
  String name(AppLocalizations l10n) => l10n.activitySenderEncrypted;

  @override
  bool operator ==(Object other) => other is ActivityEncryptedSender;

  @override
  int get hashCode => (ActivityEncryptedSender).hashCode;

  @override
  String toString() => 'ActivityEncryptedSender()';
}

/// What pays a mining reward: the chain, which has no address to show.
final class ActivityMiningReward extends ActivityUnnamedCounterparty {
  const ActivityMiningReward();

  @override
  String prefix(AppLocalizations l10n) => l10n.activityTxFrom;

  @override
  String name(AppLocalizations l10n) => l10n.activitySenderMiningReward;

  @override
  bool operator ==(Object other) => other is ActivityMiningReward;

  @override
  int get hashCode => (ActivityMiningReward).hashCode;

  @override
  String toString() => 'ActivityMiningReward()';
}

/// The recipients of a private send whose proof settled with other
/// transfers, so that none is known on its own. Named with nothing before it.
final class ActivityAggregatedBatch extends ActivityUnnamedCounterparty {
  const ActivityAggregatedBatch();

  @override
  String prefix(AppLocalizations l10n) => '';

  @override
  String name(AppLocalizations l10n) => l10n.activityTxAggregatedBatch;

  @override
  bool operator ==(Object other) => other is ActivityAggregatedBatch;

  @override
  int get hashCode => (ActivityAggregatedBatch).hashCode;

  @override
  String toString() => 'ActivityAggregatedBatch()';
}

/// What one row of an account's activity says, whichever app draws it.
@immutable
class ActivityRow {
  const ActivityRow({
    required this.label,
    required this.timeLabel,
    required this.highlight,
    required this.icon,
    required this.isSend,
    required this.amount,
    required this.hidesAmount,
    required this.counterparty,
    this.movedNothing = false,
  });

  /// What happened: "Sent", "Receiving", "Proposal approved"…
  final String label;

  /// When: "now", "5m ago", or, for a transfer scheduled to run, the time left.
  final String timeLabel;

  final ActivityHighlight highlight;
  final ActivityIcon icon;

  /// Whether the money went out of the account, so its amount is an outflow.
  final bool isSend;

  final BigInt amount;

  /// Whether there is no amount to show, as for an approval whose fee is not
  /// known: drawn as a dash in place of [amount].
  final bool hidesAmount;

  final ActivityCounterparty counterparty;

  /// Whether, in the end, [amount] did not move: a proposal cancelled or
  /// removed before it ran. Each app shows its amount as not spent.
  final bool movedNothing;

  @override
  bool operator ==(Object other) =>
      other is ActivityRow &&
      other.movedNothing == movedNothing &&
      other.label == label &&
      other.timeLabel == timeLabel &&
      other.highlight == highlight &&
      other.icon == icon &&
      other.isSend == isSend &&
      other.amount == amount &&
      other.hidesAmount == hidesAmount &&
      other.counterparty == counterparty;

  @override
  int get hashCode =>
      Object.hash(label, timeLabel, highlight, icon, isSend, amount, hidesAmount, counterparty, movedNothing);

  @override
  String toString() =>
      'ActivityRow($label, $timeLabel, $highlight, $icon, isSend: $isSend, $amount, hidesAmount: $hidesAmount, '
      '$counterparty, movedNothing: $movedNothing)';
}

/// The row [tx] makes in the activity of the account [accountId]; with
/// [isPrivate], that of an encrypted account, whose transfers are private.
/// Times are measured to [now], the clock's when not given.
ActivityRow activityRowOf(
  TransactionEvent tx, {
  required String accountId,
  required AppLocalizations l10n,
  bool isPrivate = false,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();

  ActivityRow proposalRow(
    String label, {
    required bool isUnderWay,
    required String recipient,
    required BigInt amount,
    bool mayHideAmount = true,
    bool movedNothing = false,
  }) => ActivityRow(
    label: label,
    timeLabel: isUnderWay ? l10n.activityTxTimeNow : _timeAgo(tx.timestamp, at, l10n),
    highlight: isUnderWay ? ActivityHighlight.leaving : ActivityHighlight.none,
    icon: ActivityIcon.proposal,
    isSend: true,
    amount: amount,
    hidesAmount: mayHideAmount && amount == BigInt.zero,
    counterparty: ActivityAccount(recipient, isRecipient: true),
    movedNothing: movedNothing,
  );

  ActivityRow creationRow(String label, {required bool isUnderWay, required MultisigCreationEvent event}) =>
      ActivityRow(
        label: label,
        timeLabel: isUnderWay ? l10n.activityTxTimeNow : _timeAgo(tx.timestamp, at, l10n),
        highlight: isUnderWay ? ActivityHighlight.leaving : ActivityHighlight.none,
        icon: ActivityIcon.multisig,
        isSend: true,
        amount: event.totalCost,
        hidesAmount: false,
        counterparty: ActivityMultisig(event.multisigAddress),
      );

  switch (tx) {
    case PendingMultisigProposalEvent():
      return proposalRow(
        l10n.activityTxProposing,
        isUnderWay: true,
        recipient: tx.recipient,
        amount: tx.amount,
        mayHideAmount: false,
      );
    case MultisigProposalCreatedEvent():
      return proposalRow(
        l10n.activityTxProposalCreated,
        isUnderWay: false,
        recipient: tx.recipient,
        amount: tx.amount,
        mayHideAmount: false,
      );
    case MultisigProposalApprovedEvent():
      return proposalRow(
        l10n.activityTxProposalApproved,
        isUnderWay: false,
        recipient: tx.recipient,
        amount: tx.networkFee,
      );
    case PendingMultisigApprovalEvent():
      return proposalRow(l10n.activityTxApproving, isUnderWay: true, recipient: tx.recipient, amount: tx.memberCost);
    case PendingMultisigExecutionEvent():
      return proposalRow(l10n.activityTxExecuting, isUnderWay: true, recipient: tx.recipient, amount: tx.memberCost);
    case MultisigProposalExecutedEvent():
      return proposalRow(
        l10n.activityTxProposalExecuted,
        isUnderWay: false,
        recipient: tx.recipient,
        amount: tx.networkFee,
      );
    case PendingMultisigCancellationEvent():
      return proposalRow(l10n.activityTxCancelling, isUnderWay: true, recipient: tx.recipient, amount: tx.memberCost);
    case MultisigProposalCancelledEvent():
      return proposalRow(
        l10n.activityTxProposalCancelled,
        isUnderWay: false,
        recipient: tx.recipient,
        amount: tx.networkFee,
      );
    // A multisig's own past proposal, named by how it ended.
    case MultisigProposalEvent():
      return proposalRow(
        switch (tx.status) {
          MultisigProposalStatus.executed => l10n.activityTxProposalExecuted,
          MultisigProposalStatus.cancelled => l10n.activityTxProposalCancelled,
          MultisigProposalStatus.removed => l10n.activityTxProposalRemoved,
          MultisigProposalStatus.active ||
          MultisigProposalStatus.approved ||
          MultisigProposalStatus.unknown => l10n.activityTxProposal,
        },
        isUnderWay: false,
        recipient: tx.to,
        amount: tx.amount,
        mayHideAmount: false,
        movedNothing: switch (tx.status) {
          MultisigProposalStatus.cancelled || MultisigProposalStatus.removed => true,
          _ => false,
        },
      );
    case PendingMultisigCreationEvent():
      return creationRow(l10n.activityTxMultisigCreating, isUnderWay: true, event: tx);
    case MultisigCreatedEvent():
      return creationRow(l10n.activityTxMultisigCreated, isUnderWay: false, event: tx);
  }

  final isSend = tx.from == accountId;
  final isPending = tx is PendingTransactionEvent;
  final isScheduled = tx.isReversibleScheduled;
  final isUnderWay = isPending || isScheduled;

  final String label;
  if (isPending) {
    label = isSend
        ? (isPrivate ? l10n.activityTxPrivatelySending : l10n.activityTxSending)
        : (isPrivate ? l10n.activityTxPrivatelyReceiving : l10n.activityTxReceiving);
  } else if (isScheduled) {
    label = isSend
        ? l10n.activityTxPending
        : (isPrivate ? l10n.activityTxPrivatelyReceiving : l10n.activityTxReceiving);
  } else {
    label = isSend
        ? (isPrivate ? l10n.activityTxPrivateSent : l10n.activityTxSent)
        : (isPrivate ? l10n.activityTxPrivateReceived : l10n.activityTxReceived);
  }

  final String timeLabel;
  if (isPending) {
    timeLabel = l10n.activityTxTimeNow;
  } else if (isScheduled) {
    timeLabel = _timeLeft((tx as ReversibleTransferEvent).scheduledAt.difference(at).positive, l10n);
  } else {
    timeLabel = _timeAgo(tx.timestamp, at, l10n);
  }

  final counterparty = isSend ? tx.to : tx.from;
  return ActivityRow(
    label: label,
    timeLabel: timeLabel,
    highlight: !isUnderWay
        ? ActivityHighlight.none
        : isSend
        ? ActivityHighlight.leaving
        : ActivityHighlight.arriving,
    icon: ActivityIcon.direction,
    isSend: isSend,
    amount: tx.amount,
    hidesAmount: false,
    // A mining reward has no sender, a private send whose proof settled with
    // other transfers no known recipient, and a private receipt no known
    // sender.
    counterparty: tx is MinerRewardEvent
        ? const ActivityMiningReward()
        : counterparty.isEmpty
        ? const ActivityAggregatedBatch()
        : !isSend && tx.isWormhole
        ? const ActivityEncryptedSender()
        : ActivityAccount(counterparty, isRecipient: isSend),
  );
}

String _timeLeft(Duration d, AppLocalizations l10n) {
  final days = d.inDays.toString().padLeft(2, '0');
  final hours = (d.inHours % 24).toString().padLeft(2, '0');
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  return l10n.activityTxTimeRemaining(days, hours, minutes);
}

String _timeAgo(DateTime timestamp, DateTime now, AppLocalizations l10n) {
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return l10n.activityTxTimeNow;
  if (diff.inMinutes < 60) return l10n.activityTxTimeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.activityTxTimeHoursAgo(diff.inHours);
  return l10n.activityTxTimeDaysAgo(diff.inDays);
}
