import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

/// On-chain multisig proposal execution shown in the executor's activity history.
///
/// [amount] is the proposed transfer amount (context). [fee] is the extrinsic
/// network fee paid by the executor.
class MultisigProposalExecutedEvent extends TransactionEvent {
  final String executorId;
  final String multisigAddress;
  final String recipient;
  final BigInt? fee;
  final int proposalId;
  final List<String> approvers;
  final String result;
  final MultisigProposal? proposal;

  MultisigProposalExecutedEvent({
    required super.id,
    required this.executorId,
    required this.multisigAddress,
    required this.recipient,
    required super.amount,
    required this.proposalId,
    required this.approvers,
    required this.result,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
    this.fee,
    this.proposal,
    super.extrinsicHash,
  }) : super(from: executorId, to: recipient);

  /// Network fee paid by the executor; zero when indexer did not record one.
  BigInt get networkFee => fee ?? BigInt.zero;

  /// Stable key for swapping a pending execution row with this indexed event.
  String get activityDedupKey {
    if (extrinsicHash != null) return 'hash:$extrinsicHash';
    final indexed = proposal;
    if (indexed != null) {
      return 'proposal:${indexed.multisigAddress}|${indexed.id}';
    }
    return 'event:$id';
  }

  /// Whether [other] describes the same execution as this event.
  bool isSameExecutionAs(MultisigProposalExecutedEvent other) {
    if (extrinsicHash != null && other.extrinsicHash != null && extrinsicHash == other.extrinsicHash) {
      return true;
    }
    return id == other.id;
  }

  factory MultisigProposalExecutedEvent.fromAccountEvent(Map<String, dynamic> event) {
    final executed = jsonMapRequired(event['executedMultisigProposal'], 'executedMultisigProposal');
    final eventTimestamp = event['timestamp'];
    return MultisigProposalExecutedEvent.fromExecutedGraphql(
      executed: executed,
      accountEventId: stringFromJson(event['id']),
      accountEventTimestamp: eventTimestamp != null ? dateTimeFromJson(eventTimestamp) : null,
    );
  }

  factory MultisigProposalExecutedEvent.fromExecutedGraphql({
    required Map<String, dynamic> executed,
    String? accountEventId,
    DateTime? accountEventTimestamp,
  }) {
    final proposalJson = jsonMapOrNull(executed['proposal']);
    MultisigProposal? proposal;
    String executorId = jsonMapOrNull(executed['extrinsic'])?['signer']?['id'];
    String multisigAddress = '';
    String recipient = '';
    BigInt amount = BigInt.zero;
    var proposalId = 0;

    if (proposalJson != null) {
      final msig = _minimalMultisigFromProposalJson(proposalJson, executorId);
      multisigAddress = msig.accountId;
      proposal = MultisigProposal.fromIndexerJson(proposalJson, msig: msig);
      recipient = proposal.recipient;
      amount = proposal.amount;
      proposalId = proposal.id;
    }

    final approversRaw = executed['approvers'];
    final approvers = approversRaw is List ? approversRaw.map((e) => e.toString()).toList() : <String>[];

    final block = jsonMapOrNull(executed['block']);
    final feeRaw = executed['fee'];
    final result = executed['result']?.toString() ?? '';

    return MultisigProposalExecutedEvent(
      id: accountEventId ?? stringFromJson(executed['id']),
      executorId: executorId,
      multisigAddress: multisigAddress,
      recipient: recipient,
      amount: amount,
      proposalId: proposalId,
      approvers: approvers,
      result: result,
      fee: feeRaw != null ? bigIntFromJson(feeRaw) : null,
      timestamp: accountEventTimestamp ?? dateTimeFromJson(executed['timestamp']),
      blockNumber: blockHeightFromJsonMap(block),
      blockHash: blockHashFromJsonMap(block),
      extrinsicHash: optionalExtrinsicHash(executed),
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
    return 'MultisigProposalExecuted{id: $id, executor: $executorId, '
        'multisig: $multisigAddress, proposalId: $proposalId, fee: $fee}';
  }
}
