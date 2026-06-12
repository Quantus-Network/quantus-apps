/// Shared GraphQL field selections for multisig indexer queries.
class MultisigGraphql {
  MultisigGraphql._();

  static const String _coreFields = '''
      id
      timestamp
      threshold
      nonce
      signers
      fee
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
      '''    multisigProposalCreated {
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
${MultisigProposalGraphql.fields}      }
    }''';

  /// Nested selection for `account_event.multisigSignerApproved`.
  static const String signerApprovedAccountEventSelection =
      '''    multisigSignerApproved {
      id
      fee
      approvals_count
      timestamp
      block {
        height
        hash
      }
      extrinsic {
        id
      }
      approver {
        id
      }
      proposal {
${MultisigProposalGraphql.fields}      }
    }''';

  /// Nested selection for `account_event.executedMultisigProposal`.
  static const String executedMultisigProposalAccountEventSelection =
      '''    executedMultisigProposal {
      id
      fee
      result
      approvers
      timestamp
      block {
        height
        hash
      }
      extrinsic {
        id
        signer {
          id
        }
      }
      proposal {
${MultisigProposalGraphql.fields}      }
    }''';

  /// Nested selection for `account_event.cancelledMultisigProposal`.
  static const String cancelledMultisigProposalAccountEventSelection =
      '''    cancelledMultisigProposal {
      id
      fee
      timestamp
      block {
        height
        hash
      }
      extrinsic {
        id
      }
      cancelledBy {
        id
      }
      proposal {
${MultisigProposalGraphql.fields}      }
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
        'signers': {
          '_contains': [accountIds.first],
        },
      };
    } else {
      where = {
        '_or': accountIds
            .map(
              (id) => {
                'signers': {
                  '_contains': [id],
                },
              },
            )
            .toList(),
      };
    }

    return {'where': where};
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
      updated_at
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
        threshold
        signers
        nonce
      }
      createdAtBlock {
        height
        hash
      }
      createdExtrinsic {
        id
      }''';

  /// Open proposals: active or approved status only.
  static const String openProposalsQuery =
      r'''
    query MultisigOpenProposals($multisigId: String!) {
      multisig_proposal(
        where: {_and: [
          {multisig_id: {_eq: $multisigId}},
          {status: {_in: [ACTIVE, APPROVED]}}
        ]},
        order_by: {updated_at: desc}
      ) {
''' +
      fields +
      r'''
      }
    }
  ''';

  static Map<String, dynamic> buildOpenProposalsVariables(String multisigAddress) {
    return {'multisigId': multisigAddress};
  }

  /// Past proposals: executed, cancelled, or removed status only.
  static const String pastProposalsQuery =
      r'''
    query MultisigPastProposals($multisigId: String!) {
      multisig_proposal(
        where: {_and: [
          {multisig_id: {_eq: $multisigId}},
          {status: {_in: [EXECUTED, CANCELLED, REMOVED]}}
        ]},
        order_by: {updated_at: desc}
      ) {
''' +
      fields +
      r'''
      }
    }
  ''';

  static Map<String, dynamic> buildPastProposalsVariables(String multisigAddress) {
    return {'multisigId': multisigAddress};
  }

  /// Fetches a single proposal by `(multisig_address, proposal_id)`.
  static const String proposalQuery =
      r'''
    query MultisigProposal($multisigId: String!, $proposalId: Int!) {
      multisig_proposal(
        where: {_and: [
          {multisig_id: {_eq: $multisigId}},
          {proposal_id: {_eq: $proposalId}}
        ]},
        limit: 1
      ) {
''' +
      fields +
      r'''
      }
    }
  ''';

  static Map<String, dynamic> buildProposalVariables(String multisigAddress, int proposalId) {
    return {'multisigId': multisigAddress, 'proposalId': proposalId};
  }
}
