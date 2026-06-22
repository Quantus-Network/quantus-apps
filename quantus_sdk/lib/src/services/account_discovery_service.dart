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
    final discovered = <Account>[];

    var consecutiveMissing = 0;
    var index = 0;
    while (consecutiveMissing < gapLimit) {
      final batch = <Account>[];
      for (var i = index; i < index + gapLimit; i++) {
        final keyPair = _hdWalletService.keyPairAtIndex(mnemonic, i);
        batch.add(
          Account(walletIndex: walletIndex, index: i, name: 'Account ${i + 1}', accountId: keyPair.ss58Address),
        );
      }

      final existingIds = await _findExistingAccountIds(batch.map((a) => a.accountId).toList());

      for (final account in batch) {
        if (existingIds.contains(account.accountId)) {
          discovered.add(account);
          consecutiveMissing = 0;
        } else {
          consecutiveMissing++;
          if (consecutiveMissing >= gapLimit) break;
        }
      }

      index += gapLimit;
    }

    return discovered;
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
