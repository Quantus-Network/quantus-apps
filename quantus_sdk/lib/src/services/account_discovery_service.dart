import 'dart:convert';

import 'package:quantus_sdk/quantus_sdk.dart';

class AccountDiscoveryService {
  final HdWalletService _hdWalletService;

  AccountDiscoveryService(this._hdWalletService);

  static const String _accountsQuery = r'''
    query AccountsQuery($ids: [String!]) {
      accounts: account(where: {id: {_in: $ids}}) {
        id
      }
    }
  ''';

  /// Discovers on-chain HD accounts using the BIP-44 gap-limit algorithm:
  /// scan HD indices in batches and keep going as long as accounts exist,
  /// stopping once [gapLimit] consecutive indices have no on-chain account.
  Future<List<Account>> discoverAccounts({
    required String mnemonic,
    required int walletIndex,
    int gapLimit = 20,
  }) async {
    final addressByIndex = <int, String>{};
    final used = await discoverUsedIndices(
      addressAt: (i) => addressByIndex[i] ??= _hdWalletService.keyPairAtIndex(mnemonic, i).ss58Address,
      gapLimit: gapLimit,
    );
    return [
      for (final i in used.toList()..sort())
        Account(walletIndex: walletIndex, index: i, name: 'Account ${i + 1}', accountId: addressByIndex[i]!),
    ];
  }

  /// Gap-limit scan over an arbitrary address sequence: derives addresses via
  /// [addressAt] in batches and returns the indices that exist on-chain,
  /// stopping once [gapLimit] consecutive indices are unused.
  Future<Set<int>> discoverUsedIndices({
    required String Function(int index) addressAt,
    int gapLimit = 20,
  }) async {
    final used = <int>{};

    var consecutiveMissing = 0;
    var index = 0;
    while (consecutiveMissing < gapLimit) {
      final batch = {for (var i = index; i < index + gapLimit; i++) i: addressAt(i)};
      final existingIds = await _findExistingAccountIds(batch.values.toList());

      for (final entry in batch.entries) {
        if (existingIds.contains(entry.value)) {
          used.add(entry.key);
          consecutiveMissing = 0;
        } else {
          consecutiveMissing++;
          if (consecutiveMissing >= gapLimit) break;
        }
      }

      index += gapLimit;
    }

    return used;
  }

  Future<Set<String>> _findExistingAccountIds(List<String> accountIds) async {
    if (accountIds.isEmpty) return {};

    final graphQlEndpoint = GraphQlEndpointService();
    final Map<String, dynamic> requestBody = {
      'query': _accountsQuery,
      'variables': {'ids': accountIds},
    };

    final response = await graphQlEndpoint.post(
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final Map<String, dynamic> responseBody = jsonDecode(response.body);
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final List<dynamic>? foundAccountsData = responseBody['data']?['accounts'];
    if (foundAccountsData == null) return {};

    return foundAccountsData.map((a) => a['id'] as String).toSet();
  }
}
