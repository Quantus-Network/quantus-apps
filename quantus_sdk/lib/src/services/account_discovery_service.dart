import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/extensions/keypair_extensions.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';

class AccountDiscoveryService {
  final HdWalletService _hdWalletService;
  final SubstrateService _substrateService;
  final String _graphQlEndpoint = AppConstants.graphQlEndpoint;

  AccountDiscoveryService(this._hdWalletService, this._substrateService);

  static const String _accountsQuery = r'''
    query AccountsQuery($ids: [String!]) {
      accounts(where: {id_in: $ids}) {
        id
      }
    }
  ''';

  Future<List<Account>> discoverAccounts({
    required String mnemonic,
    int count = 20,
  }) async {
    final allPossibleAccounts = <Account>[];

    // Add raw account
    final rawKeyPair = _substrateService.nonHDdilithiumKeypairFromMnemonic(
      mnemonic,
    );
    final rawAccount = Account(
      index: -1, //  indicator for a raw account
      name: 'Primary Account',
      accountId: rawKeyPair.ss58Address,
    );
    allPossibleAccounts.add(rawAccount);

    // Add HD accounts
    for (var i = 0; i < count; i++) {
      final keyPair = _hdWalletService.keyPairAtIndex(mnemonic, i);
      final account = Account(
        index: i,
        name: 'Account ${i + 1}',
        accountId: keyPair.ss58Address,
      );
      allPossibleAccounts.add(account);
    }

    final accountIds = allPossibleAccounts.map((a) => a.accountId).toList();

    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    final Map<String, dynamic> requestBody = {
      'query': _accountsQuery,
      'variables': {'ids': accountIds},
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}',
        );
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['errors'] != null) {
        throw Exception('GraphQL errors: ${responseBody['errors']}');
      }

      final List<dynamic>? foundAccountsData =
          responseBody['data']?['accounts'];

      if (foundAccountsData == null) {
        return [];
      }

      final foundAccountIds = foundAccountsData
          .map((a) => a['id'] as String)
          .toSet();

      return allPossibleAccounts
          .where((account) => foundAccountIds.contains(account.accountId))
          .toList();
    } catch (e, stackTrace) {
      print('Error discovering accounts: $e');
      print(stackTrace);
      rethrow;
    }
  }
}
