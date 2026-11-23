import 'dart:convert';
import 'dart:typed_data';

import 'package:quantus_cold_wallet/models/cold_account.dart';

/// An account with the public half of its key, which is all a device that
/// seals the recovery phrase keeps readable: enough to list the account, match
/// a request to it and export its key, and nothing that can sign.
class HeldAccount {
  final ColdAccount account;
  final String address;
  final Uint8List publicKey;

  const HeldAccount({required this.account, required this.address, required this.publicKey});

  HeldAccount withAccount(ColdAccount account) => HeldAccount(account: account, address: address, publicKey: publicKey);

  factory HeldAccount.fromJson(Map<String, dynamic> json) => HeldAccount(
    account: ColdAccount.fromJson(json),
    address: json['address'] as String,
    publicKey: base64Decode(json['publicKey'] as String),
  );

  Map<String, dynamic> toJson() => {...account.toJson(), 'address': address, 'publicKey': base64Encode(publicKey)};
}

/// Everything public about a sealed wallet. [phraseWords] is how long its
/// recovery phrase is, which the phrase itself is no longer at hand to tell.
class HeldAccounts {
  final int phraseWords;
  final List<HeldAccount> accounts;

  const HeldAccounts({required this.phraseWords, required this.accounts});

  List<ColdAccount> get coldAccounts => [for (final held in accounts) held.account];

  List<String> get addresses => [for (final held in accounts) held.address];

  HeldAccounts withAccounts(List<HeldAccount> accounts) => HeldAccounts(phraseWords: phraseWords, accounts: accounts);

  factory HeldAccounts.decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    return HeldAccounts(
      phraseWords: json['phraseWords'] as int,
      accounts: [for (final a in json['accounts'] as List) HeldAccount.fromJson(a as Map<String, dynamic>)],
    );
  }

  String encode() => jsonEncode({
    'phraseWords': phraseWords,
    'accounts': [for (final a in accounts) a.toJson()],
  });
}
