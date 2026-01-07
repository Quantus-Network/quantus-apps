import 'dart:convert';

import 'package:quantus_sdk/quantus_sdk.dart';

class AccountDiscoveryService {
  final HdWalletService _hdWalletService;
  final SubstrateService _substrateService;

  AccountDiscoveryService(this._hdWalletService, this._substrateService);

  static const String _accountsQuery = r'''
    query AccountsQuery($ids: [String!]) {
      accounts(where: {id_in: $ids}) {
        id
      }
    }
  ''';

  Future<List<Account>> discoverAccounts({required String mnemonic, required int walletIndex, int count = 20}) async {
    final allPossibleAccounts = <Account>[];

    // Add raw account
    final rawKeyPair = _substrateService.nonHDdilithiumKeypairFromMnemonic(mnemonic);
    final rawAccount = Account(
      walletIndex: walletIndex,
      index: -1, //  indicator for a raw account
      name: 'Primary Account',
      accountId: rawKeyPair.ss58Address,
    );
    allPossibleAccounts.add(rawAccount);

    // Add HD accounts
    for (var i = 0; i < count; i++) {
      final keyPair = _hdWalletService.keyPairAtIndex(mnemonic, i);
      final account = Account(
        walletIndex: walletIndex,
        index: i,
        name: 'Account ${i + 1}',
        accountId: keyPair.ss58Address,
      );
      allPossibleAccounts.add(account);
    }

    final accountIds = allPossibleAccounts.map((a) => a.accountId).toList();

    final graphQlEndpoint = GraphQlEndpointService();

    final Map<String, dynamic> requestBody = {
      'query': _accountsQuery,
      'variables': {'ids': accountIds},
    };

    try {
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

      if (foundAccountsData == null) {
        return [];
      }

      final foundAccountIds = foundAccountsData.map((a) => a['id'] as String).toSet();

      return allPossibleAccounts.where((account) => foundAccountIds.contains(account.accountId)).toList();
    } catch (e, stackTrace) {
      print('Error discovering accounts: $e');
      print(stackTrace);
      rethrow;
    }
  }
}
