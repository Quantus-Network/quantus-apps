import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/multisig_proposal_event.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

/// On-chain multisig proposal creation shown in the proposer's activity history.
///
/// Naming follows the shared transaction convention: [amount] is the proposed
/// transfer, [fee] is the extrinsic network fee, and [palletFee] is the
/// non-refundable multisig proposal fee.
class MultisigProposalCreatedEvent extends TransactionEvent {
  final String proposerId;
  final String multisigAddress;
  final String recipient;
  final BigInt palletFee;
  final BigInt deposit;
  final BigInt? fee;
  final MultisigProposal? proposal;

  MultisigProposalCreatedEvent({
    required super.id,
    required this.proposerId,
    required this.multisigAddress,
    required this.recipient,
    required super.amount,
    required this.palletFee,
    required this.deposit,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
    this.fee,
    this.proposal,
    super.extrinsicHash,
  }) : super(from: proposerId, to: recipient);

  bool isProposer(String accountId) => proposerId == accountId;

  /// Stable key for swapping a pending proposal row with this indexed event.
  String get activityDedupKey {
    if (extrinsicHash != null) return 'hash:$extrinsicHash';
    final indexed = proposal;
    if (indexed != null) {
      return 'proposal:${indexed.multisigAddress}|${indexed.id}';
    }
    return 'event:$id';
  }

  /// Whether [other] describes the same proposal creation as this event.
  bool isSameCreationAs(MultisigProposalCreatedEvent other) {
    if (extrinsicHash != null && other.extrinsicHash != null && extrinsicHash == other.extrinsicHash) {
      return true;
    }
    return id == other.id;
  }

  factory MultisigProposalCreatedEvent.fromAccountEvent(Map<String, dynamic> event) {
    final created = jsonMapRequired(event['multisigProposalCreated'], 'multisigProposalCreated');
    final eventTimestamp = event['timestamp'];
    return MultisigProposalCreatedEvent.fromProposalCreatedGraphql(
      created: created,
      accountEventId: stringFromJson(event['id']),
      accountEventTimestamp: eventTimestamp != null ? dateTimeFromJson(eventTimestamp) : null,
    );
  }

  factory MultisigProposalCreatedEvent.fromProposalCreatedGraphql({
    required Map<String, dynamic> created,
    String? accountEventId,
    DateTime? accountEventTimestamp,
  }) {
    final proposalJson = jsonMapOrNull(created['proposal']);
    MultisigProposal? proposal;
    String proposerId = '';
    String multisigAddress = '';
    String recipient = '';
    BigInt amount = BigInt.zero;

    final burnedPalletFeeRaw = created['burned_pallet_fee'] ?? created['burnedPalletFee'];
    final burnedPalletFeeOverride = burnedPalletFeeRaw != null ? bigIntFromJson(burnedPalletFeeRaw) : null;

    if (proposalJson != null) {
      final msig = _minimalMultisigFromProposalJson(proposalJson);
      multisigAddress = msig.accountId;
      proposal = MultisigProposal.fromIndexerJson(
        proposalJson,
        msig: msig,
        burnedPalletFeeOverride: burnedPalletFeeOverride,
      );
      proposerId = proposal.proposer;
      recipient = proposal.recipient;
      amount = proposal.amount;
    }

    final block = jsonMapOrNull(created['block']);
    final feeRaw = created['fee'] ?? proposalJson?['creation_network_fee'] ?? proposalJson?['creationNetworkFee'];
    final signerCount = proposal?.signerCount ?? _signerCountFromProposalJson(proposalJson);
    final palletFee =
        burnedPalletFeeOverride ??
        proposal?.burnedPalletFee ??
        (signerCount > 0 ? MultisigProposal.proposalCreationFeeFor(signerCount) : BigInt.zero);

    return MultisigProposalCreatedEvent(
      id: accountEventId ?? stringFromJson(created['id']),
      proposerId: proposerId,
      multisigAddress: multisigAddress,
      recipient: recipient,
      amount: amount,
      palletFee: palletFee,
      deposit: bigIntFromJson(created['deposit']),
      fee: feeRaw != null ? bigIntFromJson(feeRaw) : null,
      timestamp: accountEventTimestamp ?? dateTimeFromJson(created['timestamp']),
      blockNumber: blockHeightFromJsonMap(block),
      blockHash: blockHashFromJsonMap(block),
      extrinsicHash: optionalExtrinsicHash(created),
      proposal: proposal,
    );
  }

  /// Builds a history row from a pending proposal when the indexer row is not
  /// yet available.
  factory MultisigProposalCreatedEvent.fromPending(
    PendingMultisigProposalEvent pending, {
    MultisigProposal? proposal,
    String? accountEventId,
    DateTime? timestamp,
    int blockNumber = 0,
    String? blockHash,
    String? extrinsicHash,
  }) {
    return MultisigProposalCreatedEvent(
      id: accountEventId ?? pending.id,
      proposerId: pending.proposerId,
      multisigAddress: pending.multisigAddress,
      recipient: pending.recipient,
      amount: pending.amount,
      palletFee: pending.palletFee,
      deposit: pending.deposit,
      fee: pending.fee,
      timestamp: timestamp ?? pending.timestamp,
      blockNumber: blockNumber,
      blockHash: blockHash,
      extrinsicHash: extrinsicHash ?? pending.extrinsicHash,
      proposal: proposal,
    );
  }

  static int _signerCountFromProposalJson(Map<String, dynamic>? proposalJson) {
    if (proposalJson == null) return 0;
    final multisigJson = jsonMapOrNull(proposalJson['multisig']);
    final signersRaw = multisigJson?['signers'];
    if (signersRaw is List) return signersRaw.length;
    return 0;
  }

  static MultisigAccount _minimalMultisigFromProposalJson(Map<String, dynamic> proposalJson) {
    final multisigJson = jsonMapOrNull(proposalJson['multisig']);
    final address = nestedAccountId(multisigJson ?? proposalJson['multisig_id']);
    final signersRaw = multisigJson?['signers'];
    final signers = signersRaw is List ? signersRaw.map((e) => e.toString()).toList() : <String>[];
    final rawThreshold = multisigJson?['threshold'] as int?;
    final threshold = rawThreshold != null && rawThreshold >= 1 ? rawThreshold : 1;
    final proposer = nestedAccountId(proposalJson['proposer']);

    final nonceRaw = multisigJson?['nonce'];
    return MultisigAccount(
      name: '',
      accountId: address,
      signers: signers,
      threshold: threshold,
      nonce: nonceRaw != null ? bigIntFromJson(nonceRaw) : BigInt.zero,
      myMemberAccountId: proposer,
    );
  }

  @override
  String toString() {
    return 'MultisigProposalCreated{id: $id, proposer: $proposerId, '
        'multisig: $multisigAddress, amount: $amount, palletFee: $palletFee, deposit: $deposit}';
  }
}
