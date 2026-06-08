import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';

/// Multisig creation submitted on-chain but not yet indexed in activity history.
class PendingMultisigCreationEvent extends TransactionEvent {
  static final multisig_pallet.Constants _palletConstants = multisig_pallet.Constants();

  final String creatorId;
  final String multisigAddress;
  final int threshold;
  final BigInt nonce;
  final List<String> signers;
  final BigInt palletFee;
  final BigInt networkFee;
  final BigInt deposit;

  BigInt get totalCost => palletFee + networkFee + deposit;

  PendingMultisigCreationEvent({
    required String tempId,
    required this.creatorId,
    required this.multisigAddress,
    required this.threshold,
    required this.nonce,
    required this.signers,
    required this.palletFee,
    required this.networkFee,
    required this.deposit,
    required super.timestamp,
    super.extrinsicHash,
  }) : super(
         id: tempId,
         from: creatorId,
         to: multisigAddress,
         amount: palletFee + networkFee + deposit,
         blockNumber: 0,
       );

  bool isCreator(String accountId) => creatorId == accountId;

  factory PendingMultisigCreationEvent.fromDraft(MultisigAccount draft, {BigInt? networkFee}) {
    final creator = draft.creator ?? draft.myMemberAccountId;
    final palletFee = _palletConstants.multisigFee;
    final deposit = _palletConstants.multisigDeposit;
    final resolvedNetworkFee = networkFee ?? BigInt.zero;

    return PendingMultisigCreationEvent(
      tempId: 'pending_multisig_${draft.accountId}',
      creatorId: creator,
      multisigAddress: draft.accountId,
      threshold: draft.threshold,
      nonce: draft.nonce,
      signers: List<String>.from(draft.signers),
      palletFee: palletFee,
      networkFee: resolvedNetworkFee,
      deposit: deposit,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PendingMultisigCreation{id: $id, creator: $creatorId, '
        'address: $multisigAddress, threshold: $threshold}';
  }
}
