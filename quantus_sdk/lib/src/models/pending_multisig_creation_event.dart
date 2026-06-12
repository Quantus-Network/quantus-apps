import 'package:quantus_sdk/quantus_sdk.dart';

/// Multisig creation submitted on-chain but not yet indexed in activity history.
class PendingMultisigCreationEvent extends MultisigCreationEvent {
  PendingMultisigCreationEvent({
    required String tempId,
    required super.creatorId,
    required super.multisigAddress,
    required super.threshold,
    required super.nonce,
    required super.signers,
    required super.palletFee,
    required super.networkFee,
    required super.timestamp,
    super.extrinsicHash,
  }) : super(id: tempId, blockNumber: 0);

  factory PendingMultisigCreationEvent.fromDraft(MultisigAccount draft, {required BigInt networkFee}) {
    final fields = MultisigCreationDraftFields.fromDraft(draft, networkFee: networkFee);

    return PendingMultisigCreationEvent(
      tempId: 'pending_multisig_${draft.accountId}',
      creatorId: fields.creatorId,
      multisigAddress: fields.multisigAddress,
      threshold: fields.threshold,
      nonce: fields.nonce,
      signers: fields.signers,
      palletFee: fields.palletFee,
      networkFee: fields.networkFee,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PendingMultisigCreation{id: $id, creator: $creatorId, '
        'address: $multisigAddress, threshold: $threshold}';
  }
}
