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
  final BigInt palletFee;
  final BigInt networkFee;
  final BigInt deposit;

  BigInt get totalCost => palletFee + networkFee + deposit;

  MultisigCreatedEvent({
    required super.id,
    required this.creatorId,
    required this.multisigAddress,
    required this.threshold,
    required this.nonce,
    required this.signers,
    required this.palletFee,
    required this.networkFee,
    required this.deposit,
    required super.timestamp,
    required super.blockNumber,
    required super.blockHash,
    super.extrinsicHash,
  }) : super(from: creatorId, to: multisigAddress, amount: palletFee + networkFee + deposit);

  bool isCreator(String accountId) => creatorId == accountId;

  /// Builds a history row from a local draft when the indexer row is not yet
  /// available.
  factory MultisigCreatedEvent.fromDraft(
    MultisigAccount draft, {
    DateTime? timestamp,
    String? extrinsicHash,
    String? blockHash,
    BigInt? networkFee,
  }) {
    final creator = draft.creator ?? draft.myMemberAccountId;
    final palletFee = _palletConstants.multisigFee;
    final deposit = _palletConstants.multisigDeposit;
    final resolvedNetworkFee = networkFee ?? BigInt.zero;

    return MultisigCreatedEvent(
      id: 'ae-multisig-${draft.accountId}',
      creatorId: creator,
      multisigAddress: draft.accountId,
      threshold: draft.threshold,
      nonce: draft.nonce,
      signers: List<String>.from(draft.signers),
      palletFee: palletFee,
      networkFee: resolvedNetworkFee,
      deposit: deposit,
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
      palletFee: _palletConstants.multisigFee,
      networkFee: _networkFeeFromGraphql(multisig),
      deposit: _palletConstants.multisigDeposit,
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
