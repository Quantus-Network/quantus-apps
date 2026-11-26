import 'package:quantus_sdk/src/models/account_event_cursor.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_proposal_activity.dart';

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
      burned_pallet_fee
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

/// The read of what happened to multisigs' proposals since each multisig was
/// last read: who proposed, signed, executed, cancelled or removed, whoever
/// they are.
///
/// An account's history (`account_event`) files each of these under the
/// account that did it, so a multisig's other signers are not in the history
/// of the wallet's own accounts. The indexer's own table of each kind holds
/// them all.
class MultisigProposalActivityGraphql {
  MultisigProposalActivityGraphql._();

  static const _kinds = MultisigProposalActivityKind.values;

  /// What a row of [kind] is read with besides its proposal, as
  /// [MultisigProposalActivity.fromIndexerJson] parses it.
  static String _ownFields(MultisigProposalActivityKind kind) => switch (kind) {
    MultisigProposalActivityKind.created => '',
    MultisigProposalActivityKind.signed =>
      '''
    approvals_count
    approver {
      id
    }
''',
    MultisigProposalActivityKind.ready =>
      '''
    approvals_count
    extrinsic {
      signer {
        id
      }
    }
''',
    MultisigProposalActivityKind.executed =>
      '''
    result
    extrinsic {
      signer {
        id
      }
    }
''',
    MultisigProposalActivityKind.cancelled =>
      '''
    cancelledBy {
      id
    }
''',
    MultisigProposalActivityKind.removed =>
      '''
    removedBy {
      id
    }
''',
  };

  static String _alias(int multisig, MultisigProposalActivityKind kind) => 'm${multisig}_${kind.name}';

  /// Builds the query for [withCursor].length multisigs (`$multisig0..N-1`):
  /// one selection per multisig and kind, aliased `m<N>_<kind>`.
  ///
  /// A multisig read before ([withCursor]) is read on from its cursor of each
  /// kind (`$ts<N>_<kind>`, `$id<N>_<kind>`), oldest first, `$limit` rows at
  /// a time. One never read is asked only for the newest row of each kind,
  /// which is where it is read on from.
  static String buildSinceQuery({required List<bool> withCursor}) {
    if (withCursor.isEmpty) {
      throw ArgumentError.value(withCursor, 'withCursor', 'Must query at least one multisig');
    }
    final variables = [
      for (final (i, hasCursor) in withCursor.indexed) ...[
        '\$multisig$i: String!',
        if (hasCursor)
          for (final kind in _kinds) ...['\$ts${i}_${kind.name}: timestamptz!', '\$id${i}_${kind.name}: String!'],
      ],
      if (withCursor.contains(true)) '\$limit: Int!',
    ].join(', ');

    String selection(int i, bool hasCursor, MultisigProposalActivityKind kind) {
      final ofMultisig = '{proposal: {multisig_id: {_eq: \$multisig$i}}}';
      if (!hasCursor) {
        return '''
  ${_alias(i, kind)}: ${kind.table}(limit: 1, where: $ofMultisig, order_by: [{timestamp: desc}, {id: desc}]) {
    id
    timestamp
  }''';
      }
      final ts = '\$ts${i}_${kind.name}';
      final id = '\$id${i}_${kind.name}';
      return '''
  ${_alias(i, kind)}: ${kind.table}(limit: \$limit, where: {_and: [$ofMultisig, {timestamp: {_gte: $ts}}, {_not: {timestamp: {_eq: $ts}, id: {_lte: $id}}}]}, order_by: [{timestamp: asc}, {id: asc}]) {
    id
    timestamp
${_ownFields(kind)}    proposal {
${MultisigProposalGraphql.fields}
    }
  }''';
    }

    final selections = [
      for (final (i, hasCursor) in withCursor.indexed)
        for (final kind in _kinds) selection(i, hasCursor, kind),
    ].join('\n');
    return '''
query MultisigProposalActivitySince($variables) {
$selections
}
''';
  }

  /// Variables for [buildSinceQuery], for the multisigs of [after] in its
  /// order: exactly those the query declares.
  static Map<String, dynamic> sinceVariables(Map<String, MultisigProposalActivityCursor?> after, {required int limit}) {
    if (after.isEmpty) {
      throw ArgumentError.value(after, 'after', 'Must not be empty');
    }
    return {
      for (final (i, MapEntry(key: multisig, value: cursor)) in after.entries.indexed) ...{
        'multisig$i': multisig,
        if (cursor != null)
          for (final kind in _kinds) ...{
            'ts${i}_${kind.name}': _cursorOf(cursor, kind).timestamp,
            'id${i}_${kind.name}': _cursorOf(cursor, kind).id,
          },
      },
      if (after.values.any((cursor) => cursor != null)) 'limit': limit,
    };
  }

  static AccountEventCursor _cursorOf(MultisigProposalActivityCursor cursor, MultisigProposalActivityKind kind) =>
      cursor[kind] ?? (throw ArgumentError.value(cursor, 'cursor', 'Has no cursor for ${kind.name}'));

  /// Reads the answer to [buildSinceQuery] for the multisigs of [after], in
  /// its order; [multisigs] holds each of them, for its proposals to be read
  /// as that multisig's.
  ///
  /// A row that cannot be read is passed over with [onUnreadable] told: the
  /// cursor moves past it, as one bad record must not stop every later one
  /// from being read.
  static Map<String, MultisigProposalActivitySince> sinceOf(
    Map<String, dynamic> data,
    List<MultisigAccount> multisigs,
    Map<String, MultisigProposalActivityCursor?> after, {
    void Function(MultisigProposalActivityKind kind, Object? id, Object error)? onUnreadable,
  }) {
    final read = <String, MultisigProposalActivitySince>{};
    for (final (i, MapEntry(key: multisigId, value: asked)) in after.entries.indexed) {
      final msig = multisigs.where((msig) => msig.accountId == multisigId).firstOrNull;
      if (msig == null) throw ArgumentError.value(multisigs, 'multisigs', 'Does not hold $multisigId');
      final activity = <MultisigProposalActivity>[];
      final cursor = <MultisigProposalActivityKind, AccountEventCursor>{};
      for (final kind in _kinds) {
        final rows = data[_alias(i, kind)];
        if (rows is! List) {
          throw StateError('The answer is missing ${_alias(i, kind)}: ${data.keys}');
        }
        if (asked == null) {
          cursor[kind] = rows.isEmpty ? AccountEventCursor.beforeAnyEvent : _rowCursor(rows.single);
          continue;
        }
        cursor[kind] = rows.isEmpty ? _cursorOf(asked, kind) : _rowCursor(rows.last);
        for (final row in rows.cast<Map<String, dynamic>>()) {
          try {
            activity.add(MultisigProposalActivity.fromIndexerJson(kind, row, msig: msig));
          } catch (e) {
            onUnreadable?.call(kind, row['id'], e);
          }
        }
      }
      activity.sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        if (byTime != 0) return byTime;
        final byKind = a.kind.index.compareTo(b.kind.index);
        return byKind != 0 ? byKind : a.id.compareTo(b.id);
      });
      read[multisigId] = MultisigProposalActivitySince(activity: activity, cursor: cursor);
    }
    return read;
  }

  static AccountEventCursor _rowCursor(dynamic row) {
    final map = row as Map<String, dynamic>;
    final timestamp = map['timestamp'];
    final id = map['id'];
    if (timestamp is! String || id is! String) {
      throw StateError('A proposal activity row is missing the timestamp/id of its cursor: $map');
    }
    return AccountEventCursor(timestamp: timestamp, id: id);
  }
}
