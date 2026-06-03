/// Thrown when the predicted multisig address already exists on-chain.
class MultisigAlreadyExistsException implements Exception {
  MultisigAlreadyExistsException(this.address);

  final String address;

  @override
  String toString() => 'Multisig already exists at $address';
}
