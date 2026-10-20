/// Whether [address] is a multisig account, and so cannot sign a vote.
///
/// [knownMultisigs] (saved and pending multisigs on this device) answers
/// without a network call. Anything else goes to [isOnChainMultisig], which
/// reads chain storage and throws when the lookup fails.
Future<bool> isMultisigSigner(
  String address, {
  required Set<String> knownMultisigs,
  required Future<bool> Function(String address) isOnChainMultisig,
}) async {
  if (knownMultisigs.contains(address)) return true;
  return isOnChainMultisig(address);
}
