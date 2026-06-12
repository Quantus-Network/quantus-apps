import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shared multisig-creation fields and cost accounting for pending and indexed events.
abstract class MultisigCreationEvent extends TransactionEvent {
  static final multisig_pallet.Constants palletConstants = multisig_pallet.Constants();

  final String creatorId;
  final String multisigAddress;
  final int threshold;
  final BigInt nonce;
  final List<String> signers;
  final BigInt palletFee;
  final BigInt networkFee;

  BigInt get totalCost => palletFee + networkFee;

  MultisigCreationEvent({
    required super.id,
    required this.creatorId,
    required this.multisigAddress,
    required this.threshold,
    required this.nonce,
    required this.signers,
    required this.palletFee,
    required this.networkFee,
    required super.timestamp,
    required super.blockNumber,
    super.blockHash,
    super.extrinsicHash,
  }) : super(from: creatorId, to: multisigAddress, amount: palletFee + networkFee);

  bool isCreator(String accountId) => creatorId == accountId;
}

/// Resolved draft fields and pallet/network fees for a new multisig account.
class MultisigCreationDraftFields {
  const MultisigCreationDraftFields({
    required this.creatorId,
    required this.multisigAddress,
    required this.threshold,
    required this.nonce,
    required this.signers,
    required this.palletFee,
    required this.networkFee,
  });

  final String creatorId;
  final String multisigAddress;
  final int threshold;
  final BigInt nonce;
  final List<String> signers;
  final BigInt palletFee;
  final BigInt networkFee;

  BigInt get totalCost => palletFee + networkFee;

  factory MultisigCreationDraftFields.fromDraft(MultisigAccount draft, {required BigInt networkFee}) {
    return MultisigCreationDraftFields(
      creatorId: draft.creator ?? draft.myMemberAccountId,
      multisigAddress: draft.accountId,
      threshold: draft.threshold,
      nonce: draft.nonce,
      signers: List<String>.from(draft.signers),
      palletFee: MultisigCreationEvent.palletConstants.multisigFee,
      networkFee: networkFee,
    );
  }
}
