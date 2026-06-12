import 'package:quantus_sdk/quantus_sdk.dart';

/// Persisted multisig creation draft while waiting for on-chain confirmation.
class PendingMultisigCreationRecord {
  final MultisigAccount draft;
  final BigInt networkFee;
  final DateTime submittedAt;
  final String? extrinsicHash;

  const PendingMultisigCreationRecord({
    required this.draft,
    required this.networkFee,
    required this.submittedAt,
    this.extrinsicHash,
  });

  PendingMultisigCreationEvent toEvent() {
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
      timestamp: submittedAt,
      extrinsicHash: extrinsicHash,
    );
  }

  factory PendingMultisigCreationRecord.fromEvent(PendingMultisigCreationEvent event, MultisigAccount draft) {
    return PendingMultisigCreationRecord(
      draft: draft,
      networkFee: event.networkFee,
      submittedAt: event.timestamp,
      extrinsicHash: event.extrinsicHash,
    );
  }

  PendingMultisigCreationRecord copyWith({String? extrinsicHash}) {
    return PendingMultisigCreationRecord(
      draft: draft,
      networkFee: networkFee,
      submittedAt: submittedAt,
      extrinsicHash: extrinsicHash ?? this.extrinsicHash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'draft': draft.toJson(),
      'networkFee': networkFee.toString(),
      'submittedAt': submittedAt.millisecondsSinceEpoch,
      if (extrinsicHash != null) 'extrinsicHash': extrinsicHash,
    };
  }

  factory PendingMultisigCreationRecord.fromJson(Map<String, dynamic> json) {
    return PendingMultisigCreationRecord(
      draft: MultisigAccount.fromJson(json['draft'] as Map<String, dynamic>),
      networkFee: BigInt.parse(json['networkFee'] as String),
      submittedAt: DateTime.fromMillisecondsSinceEpoch(json['submittedAt'] as int),
      extrinsicHash: json['extrinsicHash'] as String?,
    );
  }

  bool isExpired({required Duration expiration}) {
    return DateTime.now().difference(submittedAt) > expiration;
  }
}
