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

  /// Builds a query for multisigs where any of [accountIds] appears in
  /// `signers` (Hasura `String[]` `_contains` per account, combined with
  /// `_or` when there are multiple wallet accounts).
  static String buildDiscoverQuery(List<String> accountIds) {
    if (accountIds.isEmpty) {
      throw ArgumentError.value(accountIds, 'accountIds', 'Must not be empty');
    }

    final whereClause = accountIds.length == 1
        ? '{signers: {_contains: ["${_escapeGraphqlString(accountIds.first)}"]}}'
        : '{_or: [${accountIds.map((id) => '{signers: {_contains: ["${_escapeGraphqlString(id)}"]}}').join(', ')}]}';

    return '''
    query DiscoverMultisigs {
      multisig(where: $whereClause) {
$discoverFields
      }
    }
  ''';
  }

  static String _escapeGraphqlString(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
