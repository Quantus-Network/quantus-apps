import 'dart:convert';
import 'dart:typed_data';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/services/cold_key_service.dart';

/// Stands in for the Rust signer and the sealed store of the device: keeps the
/// sealed phrase in memory, records the prompts its reads would raise, and
/// refuses the way the device does.
class FakeColdKeys implements ColdKeyService {
  String? sealed;

  /// What [sealed] is behind.
  SealPolicy sealedUnder = SealPolicy.biometry;

  /// The strongest policy the device enforces now; null is no screen lock.
  SealPolicy? available = SealPolicy.biometry;

  /// What each prompt said it was for.
  final prompted = <String>[];

  int get prompts => prompted.length;

  /// What the next read of the sealed phrase answers instead of releasing it.
  SealedKeyFailure? refuseNext;

  static Never _refuse(SealedKeyFailure failure) => throw SealedKeyError(failure: failure, detail: 'fake device');

  /// The address stands in for the key: it changes with the phrase, the path
  /// and the scheme, as a derived key does.
  static AccountPublicKey keyOf(String phrase, ColdAccount account) {
    final address = 'qz${phrase.hashCode.toRadixString(36)}:${account.scheme.storageName}:${account.derivationPath}';
    return AccountPublicKey(address: address, publicKey: utf8.encode(address));
  }

  static List<AccountPublicKey> _keys(String phrase, List<ColdAccount> accounts) => [
    for (final account in accounts) keyOf(phrase, account),
  ];

  String _release(String prompt) {
    prompted.add(prompt);
    final refusal = refuseNext;
    refuseNext = null;
    if (refusal != null) _refuse(refusal);
    return sealed ?? _refuse(SealedKeyFailure.missing);
  }

  void _requireAccount(ColdAccount account, String address, String prompt) {
    if (keyOf(_release(prompt), account).address != address) _refuse(SealedKeyFailure.wrongAccount);
  }

  @override
  Future<List<AccountPublicKey>> deriveKeys(String phrase, List<ColdAccount> accounts) async {
    if (phrase.split(' ').length < 12) _refuse(SealedKeyFailure.invalid);
    return _keys(phrase, accounts);
  }

  @override
  Future<SealPolicy?> availablePolicy() async => available;

  @override
  Future<SealPolicy?> sealedPolicy() async => sealed == null ? null : sealedUnder;

  @override
  Future<void> seal(String phrase, SealPolicy policy) async {
    if (available != SealPolicy.biometry && available != policy) _refuse(SealedKeyFailure.unavailable);
    sealed = phrase;
    sealedUnder = policy;
  }

  @override
  Future<void> reseal(SealPolicy policy, String prompt) async {
    await seal(_release(prompt), policy);
    _release(prompt);
  }

  @override
  Future<List<AccountPublicKey>> sealedKeys(List<ColdAccount> accounts, String prompt) async =>
      _keys(_release(prompt), accounts);

  @override
  Future<Uint8List> signExtrinsic(
    ColdAccount account,
    String address,
    Uint8List message,
    int specVersion,
    String prompt,
  ) async {
    _requireAccount(account, address, prompt);
    return Uint8List.fromList([...message, specVersion]);
  }

  @override
  Future<Uint8List> signNear(ColdAccount account, String address, List<int> transaction, String prompt) async {
    _requireAccount(account, address, prompt);
    return Uint8List.fromList(transaction);
  }

  @override
  Future<String> reveal(String prompt) async => _release(prompt);

  @override
  Future<void> delete() async => sealed = null;
}
