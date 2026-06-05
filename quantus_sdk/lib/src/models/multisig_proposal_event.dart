import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/multisig_service.dart';

/// An indexed multisig proposal surfaced in the activity feed.
class MultisigProposalEvent extends TransactionEvent {
  final MultisigProposal proposal;

  MultisigProposalEvent({required this.proposal, super.blockNumber = 0, super.extrinsicHash})
    : super(
        id: proposal.entityId,
        from: proposal.multisigAddress,
        to: proposal.recipient,
        amount: proposal.amount,
        timestamp: proposal.createdAt,
      );

  String get multisigAddress => proposal.multisigAddress;
  int get proposalId => proposal.id;
  MultisigProposalStatus get status => proposal.status;

  @override
  String toString() {
    return 'MultisigProposalEvent{entityId: $id, proposalId: $proposalId, '
        'status: $status, to: $to, amount: $amount}';
  }
}

/// A transfer proposal submitted on-chain but not yet indexed.
class PendingMultisigProposalEvent extends TransactionEvent {
  static final multisig_pallet.Constants _palletConstants = multisig_pallet.Constants();

  final String multisigAddress;
  final String proposerId;
  final String recipient;
  final BigInt fee;
  final BigInt deposit;
  final int expiryBlock;

  PendingMultisigProposalEvent({
    required String tempId,
    required this.multisigAddress,
    required this.proposerId,
    required this.recipient,
    required super.amount,
    required this.fee,
    required this.deposit,
    required this.expiryBlock,
    super.extrinsicHash,
    DateTime? timestamp,
  }) : super(
         id: tempId,
         from: multisigAddress,
         to: recipient,
         timestamp: timestamp ?? DateTime.now(),
         blockNumber: 0,
       );

  factory PendingMultisigProposalEvent.create({
    required MultisigAccount msig,
    required String proposerId,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
    BigInt? fee,
    BigInt? deposit,
  }) {
    return PendingMultisigProposalEvent(
      tempId: 'pending_proposal_${DateTime.now().millisecondsSinceEpoch}',
      multisigAddress: msig.accountId,
      proposerId: proposerId,
      recipient: recipient,
      amount: amount,
      fee: fee ?? MultisigService().proposalCreationFee(msig.signers.length),
      deposit: deposit ?? _palletConstants.proposalDeposit,
      expiryBlock: expiryBlock,
    );
  }

  @override
  String toString() {
    return 'PendingMultisigProposalEvent{id: $id, multisig: $multisigAddress, to: $recipient, amount: $amount}';
  }
}
