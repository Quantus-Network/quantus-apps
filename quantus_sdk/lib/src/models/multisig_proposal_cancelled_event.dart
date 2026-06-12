import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

/// On-chain multisig proposal cancellation shown in the proposer's activity history.
///
/// [amount] is the proposed transfer amount (context). [fee] is the extrinsic
/// network fee paid by the proposer.
class MultisigProposalCancelledEvent extends TransactionEvent {
  final String proposerId;
  final String multisigAddress;
  final String recipient;
  final BigInt? fee;
  final int proposalId;
  final MultisigProposal? proposal;

  MultisigProposalCancelledEvent({
    required super.id,
    required this.proposerId,
    required this.multisigAddress,
    required this.recipient,
    required super.amount,
    required this.proposalId,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
    this.fee,
    this.proposal,
    super.extrinsicHash,
  }) : super(from: proposerId, to: recipient);

  /// Network fee paid by the proposer; zero when indexer did not record one.
  BigInt get networkFee => fee ?? BigInt.zero;

  /// Stable key for swapping a pending cancellation row with this indexed event.
  String get activityDedupKey {
    if (extrinsicHash != null) return 'hash:$extrinsicHash';
    final indexed = proposal;
    if (indexed != null) {
      return 'proposal:${indexed.multisigAddress}|${indexed.id}';
    }
    return 'event:$id';
  }

  /// Whether [other] describes the same cancellation as this event.
  bool isSameCancellationAs(MultisigProposalCancelledEvent other) {
    if (extrinsicHash != null && other.extrinsicHash != null && extrinsicHash == other.extrinsicHash) {
      return true;
    }
    return id == other.id;
  }

  factory MultisigProposalCancelledEvent.fromAccountEvent(Map<String, dynamic> event) {
    final cancelled = jsonMapRequired(event['cancelledMultisigProposal'], 'cancelledMultisigProposal');
    final eventTimestamp = event['timestamp'];
    return MultisigProposalCancelledEvent.fromCancelledGraphql(
      cancelled: cancelled,
      accountEventId: stringFromJson(event['id']),
      accountEventTimestamp: eventTimestamp != null ? dateTimeFromJson(eventTimestamp) : null,
    );
  }

  factory MultisigProposalCancelledEvent.fromCancelledGraphql({
    required Map<String, dynamic> cancelled,
    String? accountEventId,
    DateTime? accountEventTimestamp,
  }) {
    final proposalJson = jsonMapOrNull(cancelled['proposal']);
    MultisigProposal? proposal;
    String proposerId = nestedAccountId(cancelled['cancelledBy'] ?? cancelled['cancelled_by']);
    String multisigAddress = '';
    String recipient = '';
    BigInt amount = BigInt.zero;
    var proposalId = 0;

    if (proposalJson != null) {
      final msig = _minimalMultisigFromProposalJson(proposalJson, proposerId);
      multisigAddress = msig.accountId;
      proposal = MultisigProposal.fromIndexerJson(proposalJson, msig: msig);
      recipient = proposal.recipient;
      amount = proposal.amount;
      proposalId = proposal.id;
    }

    final block = jsonMapOrNull(cancelled['block']);
    final feeRaw = cancelled['fee'];

    return MultisigProposalCancelledEvent(
      id: accountEventId ?? stringFromJson(cancelled['id']),
      proposerId: proposerId,
      multisigAddress: multisigAddress,
      recipient: recipient,
      amount: amount,
      proposalId: proposalId,
      fee: feeRaw != null ? bigIntFromJson(feeRaw) : null,
      timestamp: accountEventTimestamp ?? dateTimeFromJson(cancelled['timestamp']),
      blockNumber: blockHeightFromJsonMap(block),
      blockHash: blockHashFromJsonMap(block),
      extrinsicHash: optionalExtrinsicHash(cancelled),
      proposal: proposal,
    );
  }

  static MultisigAccount _minimalMultisigFromProposalJson(Map<String, dynamic> proposalJson, String myMemberAccountId) {
    final multisigJson = jsonMapOrNull(proposalJson['multisig']);
    final address = nestedAccountId(multisigJson ?? proposalJson['multisig_id']);
    final signersRaw = multisigJson?['signers'];
    final signers = signersRaw is List ? signersRaw.map((e) => e.toString()).toList() : <String>[];
    final threshold = _thresholdFromMultisigJson(multisigJson, signers);

    final nonceRaw = multisigJson?['nonce'];
    return MultisigAccount(
      name: '',
      accountId: address,
      signers: signers,
      threshold: threshold,
      nonce: nonceRaw != null ? bigIntFromJson(nonceRaw) : BigInt.zero,
      myMemberAccountId: myMemberAccountId,
    );
  }

  static int _thresholdFromMultisigJson(Map<String, dynamic>? multisigJson, List<String> signers) {
    if (signers.isNotEmpty && multisigJson?['threshold'] != null) {
      return multisigThresholdFromJson(multisigJson!['threshold'], signerCount: signers.length);
    }
    if (signers.isNotEmpty) return signers.length;
    return 1;
  }

  @override
  String toString() {
    return 'MultisigProposalCancelled{id: $id, proposer: $proposerId, '
        'multisig: $multisigAddress, proposalId: $proposalId, fee: $fee}';
  }
}
