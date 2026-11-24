import 'dart:typed_data';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';

/// The Rust side of a sealed wallet: public keys from a phrase still in hand,
/// and the sealed phrase, which is taken out for one operation behind one
/// system prompt and wiped before the call returns. Only public keys and
/// signatures come back, except from [reveal]. A `prompt` is what the system
/// sheet says is being confirmed. Throws [SealedKeyError].
class ColdKeyService {
  static AccountPath _path(ColdAccount account) => AccountPath(path: account.derivationPath, scheme: account.scheme);

  static List<AccountPath> _paths(List<ColdAccount> accounts) => [for (final account in accounts) _path(account)];

  /// Never touches the sealed phrase, so never prompts.
  Future<List<AccountPublicKey>> deriveKeys(String phrase, List<ColdAccount> accounts) =>
      deriveAccountKeys(phrase: phrase, accounts: _paths(accounts));

  /// The strongest policy the device enforces now: a biometric where one is
  /// enrolled, the device passcode where none is, null without a screen lock.
  Future<SealPolicy?> availablePolicy() => sealPolicyAvailable();

  /// What the sealed phrase is behind, or null when there is none. Never
  /// prompts.
  Future<SealPolicy?> sealedPolicy() => sealedPhrasePolicy();

  /// Replaces any phrase already sealed. Writing never prompts.
  Future<void> seal(String phrase, SealPolicy policy) => sealPhrase(phrase: phrase, policy: policy);

  /// Moves the sealed phrase behind [policy]: one prompt under the policy it
  /// has, one under the new, and it stays where it was unless both pass.
  Future<void> reseal(SealPolicy policy, String prompt) => resealPhrase(policy: policy, prompt: prompt);

  Future<List<AccountPublicKey>> sealedKeys(List<ColdAccount> accounts, String prompt) =>
      sealedAccountKeys(accounts: _paths(accounts), prompt: prompt);

  /// `signature ‖ public key`, refused unless [account] derives [address].
  Future<Uint8List> signExtrinsic(
    ColdAccount account,
    String address,
    Uint8List message,
    int specVersion,
    String prompt,
  ) => sealedSignExtrinsic(
    account: _path(account),
    address: address,
    message: message,
    specVersion: specVersion,
    entropy: hedgeEntropy(),
    prompt: prompt,
  );

  /// `signature ‖ public key`, refused unless [account] derives [address] and
  /// is the key [transaction] names.
  Future<Uint8List> signNear(ColdAccount account, String address, List<int> transaction, String prompt) =>
      sealedSignNear(
        account: _path(account),
        address: address,
        transaction: transaction,
        entropy: hedgeEntropy(),
        prompt: prompt,
      );

  Future<String> reveal(String prompt) => revealSealedPhrase(prompt: prompt);

  Future<void> delete() => deleteSealedPhrase();
}
