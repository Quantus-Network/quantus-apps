import 'dart:convert';
import 'dart:typed_data';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/services/cold_key_service.dart';

/// Stands in for the Rust signer and the iOS keychain: keeps the sealed phrase
/// in memory, counts the Face ID prompts its reads would raise, and refuses
/// the way the keychain does.
class FakeColdKeys implements ColdKeyService {
  String? sealed;
  int prompts = 0;

  /// What the next read of the sealed phrase answers instead of releasing it.
  SealedKeyFailure? refuseNext;

  static Never _refuse(SealedKeyFailure failure) => throw SealedKeyError(failure: failure, detail: 'fake keychain');

  /// The address stands in for the key: it changes with the phrase, the path
  /// and the scheme, as a derived key does.
  static AccountPublicKey keyOf(String phrase, ColdAccount account) {
    final address = 'qz${phrase.hashCode.toRadixString(36)}:${account.scheme.storageName}:${account.derivationPath}';
    return AccountPublicKey(address: address, publicKey: utf8.encode(address));
  }

  static List<AccountPublicKey> _keys(String phrase, List<ColdAccount> accounts) => [
    for (final account in accounts) keyOf(phrase, account),
  ];

  String _release() {
    prompts++;
    final refusal = refuseNext;
    refuseNext = null;
    if (refusal != null) _refuse(refusal);
    return sealed ?? _refuse(SealedKeyFailure.missing);
  }

  void _requireAccount(ColdAccount account, String address) {
    if (keyOf(_release(), account).address != address) _refuse(SealedKeyFailure.wrongAccount);
  }

  @override
  Future<List<AccountPublicKey>> deriveKeys(String phrase, List<ColdAccount> accounts) async {
    if (phrase.split(' ').length < 12) _refuse(SealedKeyFailure.invalid);
    return _keys(phrase, accounts);
  }

  @override
  Future<bool> hasSealedPhrase() async => sealed != null;

  @override
  Future<void> seal(String phrase) async => sealed = phrase;

  @override
  Future<List<AccountPublicKey>> sealedKeys(List<ColdAccount> accounts) async => _keys(_release(), accounts);

  @override
  Future<Uint8List> signExtrinsic(ColdAccount account, String address, Uint8List message, int specVersion) async {
    _requireAccount(account, address);
    return Uint8List.fromList([...message, specVersion]);
  }

  @override
  Future<Uint8List> signNear(ColdAccount account, String address, List<int> transaction) async {
    _requireAccount(account, address);
    return Uint8List.fromList(transaction);
  }

  @override
  Future<String> reveal() async => _release();

  @override
  Future<void> delete() async => sealed = null;
}
