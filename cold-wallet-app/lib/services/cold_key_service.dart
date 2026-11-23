import 'dart:typed_data';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';

/// The Rust side of a sealed wallet: public keys from a phrase still in hand,
/// and the sealed phrase, which is taken out for one operation behind one
/// Face ID prompt and wiped before the call returns. Only public keys and
/// signatures come back, except from [reveal]. Throws [SealedKeyError].
class ColdKeyService {
  static AccountPath _path(ColdAccount account) => AccountPath(path: account.derivationPath, scheme: account.scheme);

  static List<AccountPath> _paths(List<ColdAccount> accounts) => [for (final account in accounts) _path(account)];

  /// Never touches the sealed phrase, so never prompts.
  Future<List<AccountPublicKey>> deriveKeys(String phrase, List<ColdAccount> accounts) =>
      deriveAccountKeys(phrase: phrase, accounts: _paths(accounts));

  /// Answered from the entry's attributes, without a prompt.
  Future<bool> hasSealedPhrase() => sealedPhraseExists();

  /// Replaces any phrase already sealed. Writing never prompts.
  Future<void> seal(String phrase) => sealPhrase(phrase: phrase);

  Future<List<AccountPublicKey>> sealedKeys(List<ColdAccount> accounts) =>
      sealedAccountKeys(accounts: _paths(accounts));

  /// `signature ‖ public key`, refused unless [account] derives [address].
  Future<Uint8List> signExtrinsic(ColdAccount account, String address, Uint8List message, int specVersion) =>
      sealedSignExtrinsic(
        account: _path(account),
        address: address,
        message: message,
        specVersion: specVersion,
        entropy: hedgeEntropy(),
      );

  /// `signature ‖ public key`, refused unless [account] derives [address] and
  /// is the key [transaction] names.
  Future<Uint8List> signNear(ColdAccount account, String address, List<int> transaction) =>
      sealedSignNear(account: _path(account), address: address, transaction: transaction, entropy: hedgeEntropy());

  Future<String> reveal() => revealSealedPhrase();

  Future<void> delete() => deleteSealedPhrase();
}
