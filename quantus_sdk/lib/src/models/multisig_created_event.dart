import 'package:quantus_sdk/quantus_sdk.dart';

import 'json_dynamic_parse.dart';

/// On-chain multisig account creation shown in activity history.
class MultisigCreatedEvent extends MultisigCreationEvent {
  MultisigCreatedEvent({
    required super.id,
    required super.creatorId,
    required super.multisigAddress,
    required super.threshold,
    required super.nonce,
    required super.signers,
    required super.palletFee,
    required super.networkFee,
    required super.deposit,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
    super.extrinsicHash,
  });

  /// Builds a history row from a local draft when the indexer row is not yet
  /// available.
  factory MultisigCreatedEvent.fromDraft(
    MultisigAccount draft, {
    DateTime? timestamp,
    String? extrinsicHash,
    String? blockHash,
    BigInt? networkFee,
  }) {
    final fields = MultisigCreationDraftFields.fromDraft(draft, networkFee: networkFee);

    return MultisigCreatedEvent(
      id: 'ae-multisig-${draft.accountId}',
      creatorId: fields.creatorId,
      multisigAddress: fields.multisigAddress,
      threshold: fields.threshold,
      nonce: fields.nonce,
      signers: fields.signers,
      palletFee: fields.palletFee,
      networkFee: fields.networkFee,
      deposit: fields.deposit,
      blockHash: blockHash,
      timestamp: timestamp ?? DateTime.now(),
      blockNumber: 0,
      extrinsicHash: extrinsicHash,
    );
  }

  factory MultisigCreatedEvent.fromAccountEvent(Map<String, dynamic> event) {
    final multisig = jsonMapRequired(event['multisig'], 'multisig');
    final eventTimestamp = event['timestamp'];
    return MultisigCreatedEvent.fromMultisigGraphql(
      multisig: multisig,
      accountEventId: stringFromJson(event['id']),
      accountEventTimestamp: eventTimestamp != null ? dateTimeFromJson(eventTimestamp) : null,
    );
  }

  factory MultisigCreatedEvent.fromMultisigGraphql({
    required Map<String, dynamic> multisig,
    String? accountEventId,
    DateTime? accountEventTimestamp,
  }) {
    final address = stringFromJson(multisig['id']);
    final creator = nestedAccountId(multisig['creator']);
    final block = jsonMapOrNull(multisig['block']);
    final signersRaw = multisig['signers'];
    final signers = signersRaw is List ? signersRaw.map((e) => e.toString()).toList() : <String>[];

    final rawThreshold = multisig['threshold'] as int?;
    final threshold = rawThreshold != null && rawThreshold >= 1 ? rawThreshold : 1;

    return MultisigCreatedEvent(
      id: accountEventId ?? 'ae-multisig-$address',
      creatorId: creator,
      multisigAddress: address,
      threshold: threshold,
      nonce: bigIntFromJson(multisig['nonce']),
      signers: signers,
      palletFee: MultisigCreationEvent.palletConstants.multisigFee,
      networkFee: _networkFeeFromGraphql(multisig),
      deposit: MultisigCreationEvent.palletConstants.multisigDeposit,
      timestamp: accountEventTimestamp ?? dateTimeFromJson(multisig['timestamp']),
      blockNumber: blockHeightFromJsonMap(block),
      blockHash: blockHashFromJsonMap(block),
      extrinsicHash: optionalExtrinsicHash(multisig),
    );
  }

  static BigInt _networkFeeFromGraphql(Map<String, dynamic> multisig) {
    final raw = multisig['fee'];
    if (raw != null) return bigIntFromJson(raw);

    final extrinsic = jsonMapOrNull(multisig['extrinsic']);
    final extrinsicFee = extrinsic?['fee'];
    if (extrinsicFee != null) return bigIntFromJson(extrinsicFee);

    return BigInt.zero;
  }

  @override
  String toString() {
    return 'MultisigCreated{id: $id, creator: $creatorId, address: $multisigAddress, '
        'threshold: $threshold, palletFee: $palletFee, networkFee: $networkFee, deposit: $deposit}';
  }
}
