/// Shared GraphQL field selections for multisig indexer queries.
class MultisigGraphql {
  MultisigGraphql._();

  static const String _coreFields = '''
      id
      timestamp
      threshold
      nonce
      signers
      creator {
        id
      }
      block {
        height
        hash
      }''';

  /// Core multisig fields used by [MultisigCreatedEvent.fromMultisigGraphql].
  static const String indexerFields =
      '''
$_coreFields
      extrinsic {
        id
      }''';

  /// Fields for `multisig_by_pk` including extrinsic metadata.
  static const String byPkFields =
      '''
$_coreFields
      extrinsic {
        id
        pallet
        call
      }''';

  /// Nested selection for `account_event.multisig`.
  static const String accountEventSelection =
      '''
    multisig {
$indexerFields
    }''';

  static const String byPkQuery =
      r'''
    query MultisigByPk($id: String!) {
      multisig_by_pk(id: $id) {
''' +
      byPkFields +
      r'''
      }
    }
  ''';

  /// Fields for discovering multisigs where local accounts are signers.
  static const String discoverFields = _coreFields;

  /// Query for multisigs where any local account appears in `signers`.
  static const String discoverQuery =
      r'''
    query DiscoverMultisigs($where: multisig_bool_exp!) {
      multisig(where: $where) {
''' +
      discoverFields +
      r'''
      }
    }
  ''';

  /// Variables for [discoverQuery]: any of [accountIds] in `signers` via
  /// Hasura `String[]` `_contains`, combined with `_or` for multiple
  /// wallet accounts.
  static Map<String, dynamic> buildDiscoverVariables(List<String> accountIds) {
    if (accountIds.isEmpty) {
      throw ArgumentError.value(accountIds, 'accountIds', 'Must not be empty');
    }

    final Map<String, dynamic> where;
    if (accountIds.length == 1) {
      where = {
        'signers': {'_contains': [accountIds.first]},
      };
    } else {
      where = {
        '_or': accountIds
            .map((id) => {
                  'signers': {'_contains': [id]},
                })
            .toList(),
      };
    }

    return {'where': where};
  }
}
