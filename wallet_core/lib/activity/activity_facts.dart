import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_detail.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/transaction_event_extension.dart';

/// What a fact of a transaction's page is about. Each app names it in its
/// own words.
enum ActivityFactKind {
  /// Who was paid, or who a proposal pays.
  to,

  /// Who paid.
  from,

  /// The multisig a proposal belongs to.
  multisig,

  /// The multisig being made.
  newMultisig,

  /// How many of a new multisig's signers must approve, of how many.
  threshold,

  /// How many signers a new multisig has.
  signers,

  /// Who made a new multisig.
  creator,

  /// What a proposal moves.
  transferAmount,

  /// How many of a multisig's signers have approved a proposal.
  approvals,

  /// The pallet's fee for making a proposal.
  proposalFee,

  /// The pallet's fee for making a multisig.
  creationFee,

  /// What making a proposal holds back until it ends.
  deposit,

  /// The fee its extrinsic paid.
  networkFee,

  /// When it happened.
  date,

  /// Its extrinsic's hash.
  hash,
}

/// One fact of a transaction's page: what it is about ([kind]), and its value.
sealed class ActivityFact {
  const ActivityFact(this.kind);

  final ActivityFactKind kind;
}

/// Who was on the other side, as an activity row names them.
final class ActivityPartyFact extends ActivityFact {
  const ActivityPartyFact(super.kind, this.who);

  final ActivityCounterparty who;

  @override
  bool operator ==(Object other) => other is ActivityPartyFact && other.kind == kind && other.who == who;

  @override
  int get hashCode => Object.hash(kind, who);

  @override
  String toString() => 'ActivityPartyFact($kind, $who)';
}

/// An account, by its whole address.
final class ActivityAddressFact extends ActivityFact {
  const ActivityAddressFact(super.kind, this.address);

  final String address;

  @override
  bool operator ==(Object other) => other is ActivityAddressFact && other.kind == kind && other.address == address;

  @override
  int get hashCode => Object.hash(kind, address);

  @override
  String toString() => 'ActivityAddressFact($kind, $address)';
}

/// An amount of tokens.
final class ActivityAmountFact extends ActivityFact {
  const ActivityAmountFact(super.kind, this.amount);

  final BigInt amount;

  @override
  bool operator ==(Object other) => other is ActivityAmountFact && other.kind == kind && other.amount == amount;

  @override
  int get hashCode => Object.hash(kind, amount);

  @override
  String toString() => 'ActivityAmountFact($kind, $amount)';
}

/// A value already in words or figures, such as "2 of 3".
final class ActivityTextFact extends ActivityFact {
  const ActivityTextFact(super.kind, this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is ActivityTextFact && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'ActivityTextFact($kind, $text)';
}

/// When it happened.
final class ActivityTimeFact extends ActivityFact {
  const ActivityTimeFact(this.time) : super(ActivityFactKind.date);

  final DateTime time;

  @override
  bool operator ==(Object other) => other is ActivityTimeFact && other.time == time;

  @override
  int get hashCode => time.hashCode;

  @override
  String toString() => 'ActivityTimeFact($time)';
}

/// Its extrinsic's hash.
final class ActivityHashFact extends ActivityFact {
  const ActivityHashFact(this.hash) : super(ActivityFactKind.hash);

  final String hash;

  @override
  bool operator ==(Object other) => other is ActivityHashFact && other.hash == hash;

  @override
  int get hashCode => hash.hashCode;

  @override
  String toString() => 'ActivityHashFact($hash)';
}

/// What a transaction's page holds under its title, whichever app draws it:
/// the amount at its top and how that stands out, then its [facts] in order.
@immutable
class ActivityFacts {
  const ActivityFacts({required this.amount, required this.highlight, required this.facts});

  /// The amount the page leads with, or null when there is none to show:
  /// drawn as a dash.
  final BigInt? amount;

  final ActivityHighlight highlight;
  final List<ActivityFact> facts;

  @override
  bool operator ==(Object other) =>
      other is ActivityFacts &&
      other.amount == amount &&
      other.highlight == highlight &&
      listEquals(other.facts, facts);

  @override
  int get hashCode => Object.hash(amount, highlight, Object.hashAll(facts));

  @override
  String toString() => 'ActivityFacts($amount, $highlight, $facts)';
}

/// What [tx]'s page holds for the account [accountId].
ActivityFacts activityFactsOf(TransactionEvent tx, {required String accountId, required AppLocalizations l10n}) {
  final (amount, highlight) = _amountOf(tx, accountId);
  return ActivityFacts(amount: amount, highlight: highlight, facts: _factsOf(tx, accountId, l10n));
}

/// A fee worth showing: known, and more than nothing.
BigInt? _paid(BigInt? fee) => fee == null || fee == BigInt.zero ? null : fee;

(BigInt?, ActivityHighlight) _amountOf(TransactionEvent tx, String accountId) {
  const none = ActivityHighlight.none;
  const leaving = ActivityHighlight.leaving;
  return switch (tx) {
    // A multisig's making cost its creator only.
    PendingMultisigCreationEvent(:final creatorId) when creatorId != accountId => (null, none),
    PendingMultisigCreationEvent(:final totalCost) => (totalCost, leaving),
    MultisigCreatedEvent(:final creatorId) when creatorId != accountId => (null, none),
    MultisigCreatedEvent(:final totalCost) => (totalCost, none),
    // A proposal's later steps cost their fee.
    MultisigProposalApprovedEvent(:final fee) => (_paid(fee), none),
    MultisigProposalExecutedEvent(:final fee) => (_paid(fee), none),
    MultisigProposalCancelledEvent(:final fee) => (_paid(fee), none),
    PendingMultisigExecutionEvent(:final fee) => (_paid(fee), leaving),
    PendingMultisigCancellationEvent(:final fee) => (_paid(fee), leaving),
    _ => (tx.amount, isActivitySend(tx, accountId: accountId) ? none : ActivityHighlight.arriving),
  };
}

List<ActivityFact> _factsOf(TransactionEvent tx, String accountId, AppLocalizations l10n) {
  final hash = tx.extrinsicHash;
  final hashFact = [if (hash != null) ActivityHashFact(hash)];
  final at = ActivityTimeFact(tx.timestamp);

  List<ActivityFact> proposalMade({
    required String multisig,
    required String recipient,
    required BigInt proposalFee,
    required BigInt deposit,
    required BigInt? fee,
  }) => [
    ActivityAddressFact(ActivityFactKind.multisig, multisig),
    ActivityPartyFact(ActivityFactKind.to, ActivityAccount(recipient, isRecipient: true)),
    ActivityAmountFact(ActivityFactKind.proposalFee, proposalFee),
    ActivityAmountFact(ActivityFactKind.deposit, deposit),
    if (_paid(fee) case final paid?) ActivityAmountFact(ActivityFactKind.networkFee, paid),
    at,
    ...hashFact,
  ];

  /// A proposal's later step: what the proposal moves, then [steps], the
  /// fee, and, once in a block, when.
  List<ActivityFact> proposalStep({
    required String multisig,
    required String recipient,
    required BigInt fee,
    List<ActivityFact> steps = const [],
    bool isInBlock = true,
  }) => [
    ActivityAddressFact(ActivityFactKind.multisig, multisig),
    ActivityPartyFact(ActivityFactKind.to, ActivityAccount(recipient, isRecipient: true)),
    ActivityAmountFact(ActivityFactKind.transferAmount, tx.amount),
    ...steps,
    if (_paid(fee) case final paid?) ActivityAmountFact(ActivityFactKind.networkFee, paid),
    if (isInBlock) at,
    ...hashFact,
  ];

  /// A multisig being made: what it will be, who made it, and what it costs.
  /// While it is being made its hash is not shown.
  List<ActivityFact> multisigMade(MultisigCreationEvent made, {required bool withHash}) => [
    ActivityAddressFact(ActivityFactKind.newMultisig, made.multisigAddress),
    ActivityTextFact(
      ActivityFactKind.threshold,
      l10n.activityDetailMultisigThresholdValue(made.threshold, made.signers.length),
    ),
    ActivityTextFact(ActivityFactKind.signers, '${made.signers.length}'),
    ActivityAddressFact(ActivityFactKind.creator, made.creatorId),
    ActivityAmountFact(ActivityFactKind.creationFee, made.palletFee),
    ActivityAmountFact(ActivityFactKind.networkFee, made.networkFee),
    at,
    if (withHash) ...hashFact,
  ];

  switch (tx) {
    case PendingMultisigProposalEvent():
      return proposalMade(
        multisig: tx.multisigAddress,
        recipient: tx.recipient,
        proposalFee: tx.palletFee,
        deposit: tx.deposit,
        fee: tx.fee,
      );
    case MultisigProposalCreatedEvent():
      return proposalMade(
        multisig: tx.multisigAddress,
        recipient: tx.recipient,
        proposalFee: tx.palletFee,
        deposit: tx.deposit,
        fee: tx.fee,
      );
    case MultisigProposalApprovedEvent():
      return proposalStep(
        multisig: tx.multisigAddress,
        recipient: tx.recipient,
        fee: tx.networkFee,
        steps: [
          ActivityTextFact(
            ActivityFactKind.approvals,
            tx.approvalsOfSignersLabel(l10n.multisigApprovalsOf) ?? '${tx.approvalsCount}',
          ),
        ],
      );
    case PendingMultisigExecutionEvent():
      return proposalStep(
        multisig: tx.multisigAddress,
        recipient: tx.recipient,
        fee: tx.fee ?? BigInt.zero,
        isInBlock: false,
      );
    case MultisigProposalExecutedEvent():
      return proposalStep(multisig: tx.multisigAddress, recipient: tx.recipient, fee: tx.networkFee);
    case PendingMultisigCancellationEvent():
      return proposalStep(
        multisig: tx.multisigAddress,
        recipient: tx.recipient,
        fee: tx.fee ?? BigInt.zero,
        isInBlock: false,
      );
    case MultisigProposalCancelledEvent():
      return proposalStep(multisig: tx.multisigAddress, recipient: tx.recipient, fee: tx.networkFee);
    case PendingMultisigCreationEvent():
      return multisigMade(tx, withHash: false);
    case MultisigCreatedEvent():
      return multisigMade(tx, withHash: true);
  }

  final isSend = isActivitySend(tx, accountId: accountId);
  final counterparty = isSend ? tx.to : tx.from;
  final fee = switch (tx) {
    TransferEvent(:final fee) => fee,
    PendingTransactionEvent(:final fee) => fee,
    _ => null,
  };
  return [
    ActivityPartyFact(
      isSend ? ActivityFactKind.to : ActivityFactKind.from,
      // A mining reward has no sender, a private send whose proof settled
      // with other transfers no known recipient, and a private receipt no
      // known sender.
      tx is MinerRewardEvent
          ? const ActivityMiningReward()
          : counterparty.isEmpty
          ? const ActivityAggregatedBatch()
          : !isSend && tx.isWormhole
          ? const ActivityEncryptedSender()
          : ActivityAccount(counterparty, isRecipient: isSend),
    ),
    at,
    if (_paid(fee) case final paid?) ActivityAmountFact(ActivityFactKind.networkFee, paid),
    ...hashFact,
  ];
}
