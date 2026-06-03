import 'package:quantus_sdk/src/models/multisig_account.dart';

/// Result of submitting a create-multisig extrinsic to the node.
class MultisigCreateSubmission {
  const MultisigCreateSubmission({
    required this.extrinsicHash,
    required this.predictedAddress,
    required this.draft,
  });

  final String extrinsicHash;
  final String predictedAddress;
  final MultisigAccount draft;
}

/// Thrown when the predicted multisig address already exists on-chain.
class MultisigAlreadyExistsException implements Exception {
  MultisigAlreadyExistsException(this.address);

  final String address;

  @override
  String toString() => 'Multisig already exists at $address';
}
