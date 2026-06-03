import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';

import 'json_dynamic_parse.dart';

/// On-chain multisig account creation shown in activity history.
class MultisigCreatedEvent extends TransactionEvent {
  static final multisig_pallet.Constants _palletConstants = multisig_pallet.Constants();

  final String creatorId;
  final String multisigAddress;
  final int threshold;
  final BigInt nonce;
  final List<String> signers;
  final BigInt creationFee;
  final BigInt deposit;

  MultisigCreatedEvent({
    required super.id,
    required this.creatorId,
    required this.multisigAddress,
    required this.threshold,
    required this.nonce,
    required this.signers,
    required this.creationFee,
    required this.deposit,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
    super.extrinsicHash,
  }) : super(from: creatorId, to: multisigAddress, amount: creationFee);

  bool isCreator(String accountId) => creatorId == accountId;

  /// Builds a history row from a local draft when the indexer row is not yet
  /// available.
  factory MultisigCreatedEvent.fromDraft(
    MultisigAccount draft, {
    DateTime? timestamp,
    String? extrinsicHash,
    String? blockHash,
  }) {
    final creator = draft.creator ?? draft.myMemberAccountId;
    return MultisigCreatedEvent(
      id: 'ae-multisig-${draft.accountId}',
      creatorId: creator,
      multisigAddress: draft.accountId,
      threshold: draft.threshold,
      nonce: draft.nonce,
      signers: List<String>.from(draft.signers),
      creationFee: _palletConstants.multisigFee,
      deposit: _palletConstants.multisigDeposit,
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
      creationFee: _feeFromGraphql(multisig),
      deposit: _depositFromGraphql(multisig),
      timestamp: accountEventTimestamp ?? dateTimeFromJson(multisig['timestamp']),
      blockNumber: blockHeightFromJsonMap(block),
      blockHash: blockHashFromJsonMap(block),
      extrinsicHash: optionalExtrinsicHash(multisig),
    );
  }

  static BigInt _feeFromGraphql(Map<String, dynamic> multisig) {
    final raw = multisig['fee'] ?? multisig['creationFee'];
    if (raw != null) return bigIntFromJson(raw);
    return _palletConstants.multisigFee;
  }

  static BigInt _depositFromGraphql(Map<String, dynamic> multisig) {
    final raw = multisig['deposit'];
    if (raw != null) return bigIntFromJson(raw);
    return _palletConstants.multisigDeposit;
  }

  @override
  String toString() {
    return 'MultisigCreated{id: $id, creator: $creatorId, address: $multisigAddress, '
        'threshold: $threshold, fee: $creationFee, deposit: $deposit}';
  }
}
