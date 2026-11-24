import 'package:quantus_sdk/quantus_sdk.dart';

/// The fewest signers a multisig can be created with.
const minMultisigSigners = 2;

/// Why an address cannot be added as a signer.
enum SignerProblem {
  invalid,
  duplicate,

  /// A multisig has no key and cannot sign, so a multisig listing it as a
  /// signer could never execute from this wallet.
  isMultisig,
}

/// What stops [address] joining [signers], or null when nothing does.
SignerProblem? newSignerProblem(
  String address, {
  required bool Function(String address) isValidAddress,
  required List<String> signers,
  required Set<String> reserved,
}) {
  if (!isValidAddress(address)) return SignerProblem.invalid;
  if (signers.contains(address)) return SignerProblem.duplicate;
  if (reserved.contains(address)) return SignerProblem.isMultisig;
  return null;
}

/// The addresses a new multisig cannot take or list as a signer: those of the
/// [saved] multisigs and of those still [creating].
Set<String> reservedMultisigAddresses({
  required Iterable<MultisigAccount> saved,
  required Iterable<PendingMultisigCreationEvent> creating,
}) => {...saved.map((a) => a.accountId), ...creating.map((e) => e.multisigAddress)};

/// A multisig's signers: its payer, when there is one, then [others].
List<String> multisigSigners(String? payerId, List<String> others) => [?payerId, ...others];

/// Whether the form holds everything a creation needs.
bool canCreateMultisig({
  required String name,
  required List<String> signers,
  required bool hasPayer,
  required BigInt? nonce,
  required bool isPreviewing,
  required bool isSubmitting,
}) =>
    name.trim().isNotEmpty &&
    signers.length >= minMultisigSigners &&
    hasPayer &&
    nonce != null &&
    !isPreviewing &&
    !isSubmitting;
