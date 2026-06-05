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

  /// Nested selection for `account_event.multisigProposalCreated`.
  static const String proposalCreatedAccountEventSelection =
      '''
    multisigProposalCreated {
      id
      fee
      deposit
      burned_pallet_fee
      timestamp
      block {
        height
        hash
      }
      extrinsic {
        id
      }
      proposal {
''' +
      MultisigProposalGraphql.fields +
      '''
      }
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

/// Shared GraphQL field selections for multisig proposal indexer queries.
///
/// Scalar columns use snake_case (matching Hasura/Postgres). Object relations
/// use camelCase (e.g. [transferTo], [createdAtBlock]) as exposed by Hasura.
class MultisigProposalGraphql {
  MultisigProposalGraphql._();

  /// Fields selected for a `multisig_proposal` row.
  static const String fields = '''
      id
      proposal_id
      created_at
      pallet
      call
      call_raw
      transfer_amount
      status
      expiry_block
      deposit
      burned_pallet_fee
      creation_network_fee
      approvals
      decode_error
      proposer {
        id
      }
      transferTo {
        id
      }
      multisig {
        id
      }
      createdAtBlock {
        height
        hash
      }
      createdExtrinsic {
        id
      }''';

  /// Open proposals: active or approved status only.
  static String buildOpenProposalsQuery(String multisigAddress) {
    final escaped = MultisigGraphql._escapeGraphqlString(multisigAddress);
    return '''
    query MultisigOpenProposals {
      multisig_proposal(
        where: {_and: [
          {multisig_id: {_eq: "$escaped"}},
          {status: {_in: [ACTIVE, APPROVED]}}
        ]},
        order_by: {created_at: desc}
      ) {
$fields
      }
    }
  ''';
  }

  /// Past proposals: executed, cancelled, or removed status only.
  static String buildPastProposalsQuery(String multisigAddress) {
    final escaped = MultisigGraphql._escapeGraphqlString(multisigAddress);
    return '''
    query MultisigPastProposals {
      multisig_proposal(
        where: {_and: [
          {multisig_id: {_eq: "$escaped"}},
          {status: {_in: [EXECUTED, CANCELLED, REMOVED]}}
        ]},
        order_by: {created_at: desc}
      ) {
$fields
      }
    }
  ''';
  }

  /// Fetches a single proposal by `(multisig_address, proposal_id)`.
  static String buildProposalQuery(String multisigAddress, int proposalId) {
    final escaped = MultisigGraphql._escapeGraphqlString(multisigAddress);
    return '''
    query MultisigProposal {
      multisig_proposal(
        where: {_and: [{multisig_id: {_eq: "$escaped"}}, {proposal_id: {_eq: $proposalId}}]},
        limit: 1
      ) {
$fields
      }
    }
  ''';
  }
}
