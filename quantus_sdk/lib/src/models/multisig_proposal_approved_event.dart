import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';

/// On-chain multisig proposal approval shown in the approver's activity history.
///
/// [amount] is the proposed transfer amount (context). [fee] is the extrinsic
/// network fee paid by the approver.
class MultisigProposalApprovedEvent extends TransactionEvent {
  final String approverId;
  final String multisigAddress;
  final String recipient;
  final BigInt? fee;
  final int proposalId;
  final int approvalsCount;
  final MultisigProposal? proposal;

  MultisigProposalApprovedEvent({
    required super.id,
    required this.approverId,
    required this.multisigAddress,
    required this.recipient,
    required super.amount,
    required this.proposalId,
    required this.approvalsCount,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
    this.fee,
    this.proposal,
    super.extrinsicHash,
  }) : super(from: approverId, to: recipient);

  /// Network fee paid by the approver; zero when indexer did not record one.
  BigInt get networkFee => fee ?? BigInt.zero;

  /// Whether [other] describes the same approval as this event.
  bool isSameApprovalAs(MultisigProposalApprovedEvent other) {
    if (extrinsicHash != null && other.extrinsicHash != null && extrinsicHash == other.extrinsicHash) {
      return true;
    }
    return id == other.id;
  }

  factory MultisigProposalApprovedEvent.fromAccountEvent(Map<String, dynamic> event) {
    final approved = jsonMapRequired(event['multisigSignerApproved'], 'multisigSignerApproved');
    final eventTimestamp = event['timestamp'];
    return MultisigProposalApprovedEvent.fromSignerApprovedGraphql(
      approved: approved,
      accountEventId: stringFromJson(event['id']),
      accountEventTimestamp: eventTimestamp != null ? dateTimeFromJson(eventTimestamp) : null,
    );
  }

  factory MultisigProposalApprovedEvent.fromSignerApprovedGraphql({
    required Map<String, dynamic> approved,
    String? accountEventId,
    DateTime? accountEventTimestamp,
  }) {
    final proposalJson = jsonMapOrNull(approved['proposal']);
    MultisigProposal? proposal;
    String approverId = nestedAccountId(approved['approver']);
    String multisigAddress = '';
    String recipient = '';
    BigInt amount = BigInt.zero;
    var proposalId = 0;

    if (proposalJson != null) {
      final msig = _minimalMultisigFromProposalJson(proposalJson, approverId);
      multisigAddress = msig.accountId;
      proposal = MultisigProposal.fromIndexerJson(proposalJson, msig: msig);
      recipient = proposal.recipient;
      amount = proposal.amount;
      proposalId = proposal.id;
    }

    final approvalsCountRaw = approved['approvals_count'] ?? approved['approvalsCount'];
    final approvalsCount = approvalsCountRaw is int
        ? approvalsCountRaw
        : approvalsCountRaw is num
        ? approvalsCountRaw.toInt()
        : int.tryParse(approvalsCountRaw?.toString() ?? '') ?? proposal?.approvalCount ?? 0;

    final block = jsonMapOrNull(approved['block']);
    final feeRaw = approved['fee'];

    return MultisigProposalApprovedEvent(
      id: accountEventId ?? stringFromJson(approved['id']),
      approverId: approverId,
      multisigAddress: multisigAddress,
      recipient: recipient,
      amount: amount,
      proposalId: proposalId,
      approvalsCount: approvalsCount,
      fee: feeRaw != null ? bigIntFromJson(feeRaw) : null,
      timestamp: accountEventTimestamp ?? dateTimeFromJson(approved['timestamp']),
      blockNumber: blockHeightFromJsonMap(block),
      blockHash: blockHashFromJsonMap(block),
      extrinsicHash: optionalExtrinsicHash(approved),
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

  /// Approval count formatted against total signer count when known.
  String? approvalsOfSignersLabel(String Function(int count, int total) formatter) {
    final total = proposal?.signerCount ?? 0;
    if (total <= 0) return null;
    return formatter(approvalsCount, total);
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
    return 'MultisigProposalApproved{id: $id, approver: $approverId, '
        'multisig: $multisigAddress, proposalId: $proposalId, fee: $fee}';
  }
}
