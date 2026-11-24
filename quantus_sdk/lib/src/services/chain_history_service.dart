import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/json_dynamic_parse.dart';
import 'package:quantus_sdk/src/services/multisig_graphql.dart';
import 'package:quantus_sdk/src/utils/timing.dart';

class OtherTransfersResult {
  final List<TransactionEvent> transfers;
  final bool hasMore;

  /// Where the next page starts. Advances past skipped (null-parsed) rows too,
  /// so paging never re-reads them.
  final AccountEventCursor? nextCursor;

  const OtherTransfersResult({required this.transfers, required this.hasMore, required this.nextCursor});
}

/// One page of parsed `account_event` rows plus the keyset to continue from.
class AccountEventPage<T> {
  final List<T> items;
  final bool hasMore;

  /// Cursor of the last raw row consumed (parsed or skipped), or the cursor
  /// this page was requested with when it returned nothing.
  final AccountEventCursor? nextCursor;

  const AccountEventPage({required this.items, required this.hasMore, required this.nextCursor});
}

/// What an account received since it was last read, oldest first, and where
/// its next read starts.
class IncomingSince {
  /// The transfers to the account and the reversible transfers scheduled to
  /// it.
  final List<TransactionEvent> received;

  /// The last row read, or the cursor the read was asked with when there was
  /// none.
  final AccountEventCursor cursor;

  const IncomingSince({required this.received, required this.cursor});
}

class ChainHistoryService {
  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();

  static const _logName = 'ChainHistoryService';

  ChainHistoryService();

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: _logName, error: error, stackTrace: stackTrace);
  }

  /// `order_by` for one account's `account_event` selection.
  ///
  /// Rows are consumed in `(timestamp desc, id desc)` order; every keyset
  /// predicate and cursor below assumes it. The leading `account_id` (and the
  /// direction flag for send / receive) are constants under the `_eq` filters,
  /// so they do not change the order — they are there so the ORDER BY matches
  /// the `(account_id[, incoming|outgoing], timestamp, id)` index prefix.
  /// Without them the planner walks the global `timestamp` index backwards
  /// filtering row by row; on Planck that was 14s / 1.6M rows to find zero
  /// incoming rows for a send-only account, versus 4ms on the composite.
  static String _accountEventOrder(TransactionFilter filter) {
    final direction = switch (filter) {
      TransactionFilter.send => '{outgoing: desc}, ',
      TransactionFilter.receive => '{incoming: desc}, ',
      TransactionFilter.all => '',
    };
    return 'order_by: [{account_id: desc}, $direction{timestamp: desc}, {id: desc}]';
  }

  /// Variables declared by the cursor variant of a query.
  static const String _cursorVariables = ', \$cursorTimestamp: timestamptz!, \$cursorId: String!';

  /// Alias of the selection for the account at [index]; the response is
  /// reassembled by [mergeAccountEventRows].
  static String _accountAlias(int index) => 'events$index';

  /// `$account0: String!, $account1: String!, ...` for [accountCount] accounts.
  ///
  /// Each account gets its own `_eq` selection instead of one `_in` list:
  /// Hasura renders `_in` as `account_id = ANY(array)`, which Postgres will
  /// not use as an ordered range scan on the composite index.
  static String _accountVariables(int accountCount) {
    if (accountCount < 1) {
      throw ArgumentError.value(accountCount, 'accountCount', 'Must query at least one account');
    }
    return [for (var i = 0; i < accountCount; i++) '\$account$i: String!'].join(', ');
  }

  /// Keyset predicate for rows strictly after the cursor in [_accountEventOrder].
  ///
  /// `ts <= c AND NOT (ts = c AND id >= cid)` keeps a single ordered range scan
  /// on the `(account_id, ..., timestamp, id)` index; the equivalent `_or`
  /// form plans as a BitmapOr followed by a sort over the whole history.
  static const String _cursorPredicate =
      '{timestamp: {_lte: \$cursorTimestamp}}, {_not: {timestamp: {_eq: \$cursorTimestamp}, id: {_gte: \$cursorId}}}';

  /// Direction column predicate for [filter], or empty for [TransactionFilter.all].
  ///
  /// `outgoing` / `incoming` are set by the indexer per (account, event) row
  /// so send / receive history never has to join the payload relations.
  static String _directionPredicate(TransactionFilter filter) {
    switch (filter) {
      case TransactionFilter.send:
        return ', {outgoing: {_eq: true}}';
      case TransactionFilter.receive:
        return ', {incoming: {_eq: true}}';
      case TransactionFilter.all:
        return '';
    }
  }

  /// Builds the pending-scheduled-reversible-transfers query for
  /// [accountCount] accounts, one aliased selection per account.
  ///
  /// With [withCursor], the query declares `$cursorTimestamp` / `$cursorId`
  /// and only returns rows strictly after that keyset.
  @visibleForTesting
  static String buildScheduledReversibleTransfersQuery(
    TransactionFilter filter, {
    required bool withCursor,
    required int accountCount,
  }) {
    String whereClause(int index) =>
        '{_and: [{account_id: {_eq: \$account$index}}, {scheduled_reversible_transfer_id: {_is_null: false}}'
        '${_directionPredicate(filter)}'
        ', {scheduledReversibleTransfer: {scheduled_at: {_gt: \$after}}}'
        '${withCursor ? ', $_cursorPredicate' : ''}]}';

    const selection =
        '''
    id
    timestamp
    scheduledReversibleTransfer {
$_scheduledTransferFields
    }''';

    return _accountEventDocument(
      operationName: 'ScheduledReversibleTransfersByAccounts',
      extraVariables: ', \$after: timestamptz!',
      filter: filter,
      withCursor: withCursor,
      accountCount: accountCount,
      whereClause: whereClause,
      selection: selection,
    );
  }

  /// What a scheduled transfer is read with, as [ReversibleTransferEvent.fromJson]
  /// parses it.
  static const _scheduledTransferFields = '''
      id
      amount
      timestamp
      from {
        id
      }
      to {
        id
      }
      txId: tx_id
      scheduledAt: scheduled_at
      block {
        height
        hash
      }
      extrinsic {
        id
      }''';

  /// What a transfer is read with, as [_transferEvent] parses it: the pallet
  /// tells a wormhole receipt apart.
  static const _transferFields = '''
      id
      amount
      timestamp
      from {
        id
      }
      to {
        id
      }
      block {
        height
        hash
      }
      extrinsic {
        id
        pallet
      }
      fee''';

  /// How many still-scheduled transfers, or ids asked about, one request
  /// takes: under the indexer's 1000 rows a selection.
  static const _stillScheduledPage = 500;

  /// Builds the query for the transfers still scheduled to or from
  /// [accountCount] accounts (`$account0..N-1`): scheduled from `$after` on,
  /// `$limit` at a time in order of id, after `$afterId` with [withCursor].
  ///
  /// It reads `scheduled_reversible_transfer` itself, on plain columns only,
  /// so Postgres serves it from the `scheduled_at` index: what is scheduled
  /// network-wide from that time on, a small set however long any account's
  /// history. Through the accounts' history (`account_event`), an account with
  /// nothing scheduled, as most have, would be read whole.
  @visibleForTesting
  static String buildStillScheduledQuery({required int accountCount, required bool withCursor}) {
    final variables =
        '${_accountVariables(accountCount)}, \$after: timestamptz!, \$limit: Int!'
        '${withCursor ? ', \$afterId: String!' : ''}';
    final accounts = '[${[for (var i = 0; i < accountCount; i++) '\$account$i'].join(', ')}]';
    final where =
        '{_and: [{scheduled_at: {_gt: \$after}}, {_or: [{from_id: {_in: $accounts}}, {to_id: {_in: $accounts}}]}'
        '${withCursor ? ', {id: {_gt: \$afterId}}' : ''}]}';
    return '''
query StillScheduledTransfers($variables) {
  scheduled: scheduled_reversible_transfer(limit: \$limit, where: $where, order_by: {id: asc}) {
$_scheduledTransferFields
  }
}
''';
  }

  /// Builds the query for which of [idCount] scheduled transfers (`$id0..N-1`)
  /// were executed and which were cancelled, by the scheduled transfer's id:
  /// a plain, indexed column of each.
  @visibleForTesting
  static String buildSettledScheduledQuery({required int idCount}) {
    if (idCount < 1) {
      throw ArgumentError.value(idCount, 'idCount', 'Must ask about at least one scheduled transfer');
    }
    final variables = [for (var i = 0; i < idCount; i++) '\$id$i: String!'].join(', ');
    final ids = '[${[for (var i = 0; i < idCount; i++) '\$id$i'].join(', ')}]';
    return '''
query SettledScheduledTransfers($variables) {
  executed: executed_reversible_transfer(where: {scheduled_transfer_id: {_in: $ids}}) {
    scheduledTransfer: scheduled_transfer_id
  }
  cancelled: cancelled_reversible_transfer(where: {scheduled_transfer_id: {_in: $ids}}) {
    scheduledTransfer: scheduled_transfer_id
  }
}
''';
  }

  /// The scheduled transfers among [rows] that [settled] (the answer to
  /// [buildSettledScheduledQuery]) does not say were executed or cancelled.
  @visibleForTesting
  static List<ReversibleTransferEvent> stillScheduledOf(List<dynamic> rows, Map<String, dynamic> settled) {
    final ended = {
      for (final kind in const ['executed', 'cancelled'])
        for (final row in settled[kind] as List<dynamic>) (row as Map<String, dynamic>)['scheduledTransfer'] as String,
    };
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        if (!ended.contains(row['id']))
          ReversibleTransferEvent.fromJson(row, status: ReversibleTransferStatus.SCHEDULED),
    ];
  }

  /// The transfers still scheduled to or from [accountIds]: scheduled from two
  /// minutes ago on, as the history counts them, and neither executed nor
  /// cancelled. One request reads them; only when there are some does a
  /// second ask which were executed or cancelled.
  Future<List<ReversibleTransferEvent>> fetchStillScheduledTransfers({required List<String> accountIds}) async {
    if (accountIds.isEmpty) {
      throw ArgumentError.value(accountIds, 'accountIds', 'Must not be empty');
    }
    final pendingSince = DateTime.now().subtract(const Duration(minutes: 2)).toUtc().toIso8601String();
    final accounts = {for (final (i, id) in accountIds.indexed) 'account$i': id};
    final sw = Stopwatch()..start();
    try {
      final rows = <dynamic>[];
      String? afterId;
      while (true) {
        final data = await _graphQlEndpointService.query(
          document: buildStillScheduledQuery(accountCount: accountIds.length, withCursor: afterId != null),
          variables: {...accounts, 'after': pendingSince, 'limit': _stillScheduledPage, 'afterId': ?afterId},
        );
        final page = data['scheduled'] as List<dynamic>;
        rows.addAll(page);
        if (page.length < _stillScheduledPage) break;
        afterId = (page.last as Map<String, dynamic>)['id'] as String;
      }
      if (rows.isEmpty) return const [];

      final ids = [for (final row in rows.cast<Map<String, dynamic>>()) row['id'] as String];
      final settled = <String, dynamic>{'executed': <dynamic>[], 'cancelled': <dynamic>[]};
      for (var start = 0; start < ids.length; start += _stillScheduledPage) {
        final chunk = ids.sublist(
          start,
          start + _stillScheduledPage > ids.length ? ids.length : start + _stillScheduledPage,
        );
        final data = await _graphQlEndpointService.query(
          document: buildSettledScheduledQuery(idCount: chunk.length),
          variables: {for (final (i, id) in chunk.indexed) 'id$i': id},
        );
        for (final kind in const ['executed', 'cancelled']) {
          (settled[kind] as List<dynamic>).addAll(data[kind] as List<dynamic>);
        }
      }
      return stillScheduledOf(rows, settled);
    } catch (e, stackTrace) {
      _log('Error fetching still-scheduled transfers: $e', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      sw.stop();
      printTiming('fetchStillScheduledTransfers', sw.elapsedMilliseconds);
    }
  }

  /// How many rows one read takes of what an account received: under the
  /// indexer's 1000 rows a selection. An account that received more is read
  /// on by the next read.
  static const _incomingSincePage = 100;

  /// Where an account with no incoming history is read on from: every row is
  /// strictly after it.
  static const _beforeAnyEvent = AccountEventCursor(timestamp: '1970-01-01T00:00:00+00:00', id: '');

  /// Builds the query for what accounts received since each was last read:
  /// one selection per account (`$account0..N-1`), aliased `events0..N-1`.
  ///
  /// An account read before ([withCursor]) is read on from its own cursor
  /// (`$cursorTimestampN`, `$cursorIdN`), oldest first, `$limit` rows at a
  /// time. One never read is asked only for its newest incoming row, which is
  /// where it is read on from.
  ///
  /// Every predicate is a plain column and the order follows the
  /// `(account_id, incoming, timestamp, id)` index, so each selection is one
  /// range scan from the cursor to the end of the account's incoming rows.
  @visibleForTesting
  static String buildIncomingSinceQuery({required List<bool> withCursor}) {
    if (withCursor.isEmpty) {
      throw ArgumentError.value(withCursor, 'withCursor', 'Must query at least one account');
    }
    final variables = [
      for (final (i, hasCursor) in withCursor.indexed) ...[
        '\$account$i: String!',
        if (hasCursor) ...['\$cursorTimestamp$i: timestamptz!', '\$cursorId$i: String!'],
      ],
      if (withCursor.contains(true)) '\$limit: Int!',
    ].join(', ');

    String selection(int i, bool hasCursor) {
      const incoming = '{incoming: {_eq: true}}';
      if (!hasCursor) {
        return '''
  ${_accountAlias(i)}: account_event(limit: 1, where: {_and: [{account_id: {_eq: \$account$i}}, $incoming]}, ${_accountEventOrder(TransactionFilter.receive)}) {
    id
    timestamp
  }''';
      }
      return '''
  ${_accountAlias(i)}: account_event(limit: \$limit, where: {_and: [{account_id: {_eq: \$account$i}}, $incoming, {timestamp: {_gte: \$cursorTimestamp$i}}, {_not: {timestamp: {_eq: \$cursorTimestamp$i}, id: {_lte: \$cursorId$i}}}]}, order_by: [{account_id: asc}, {incoming: asc}, {timestamp: asc}, {id: asc}]) {
    id
    timestamp
    transfer {
$_transferFields
    }
    scheduledReversibleTransfer {
$_scheduledTransferFields
    }
  }''';
    }

    return '''
query IncomingSince($variables) {
${[for (final (i, hasCursor) in withCursor.indexed) selection(i, hasCursor)].join('\n')}
}
''';
  }

  /// Variables for [buildIncomingSinceQuery], for the accounts of [after] in
  /// its order: exactly those the query declares.
  @visibleForTesting
  static Map<String, dynamic> incomingSinceVariables(Map<String, AccountEventCursor?> after, {required int limit}) {
    if (after.isEmpty) {
      throw ArgumentError.value(after, 'after', 'Must not be empty');
    }
    return {
      for (final (i, MapEntry(key: account, value: cursor)) in after.entries.indexed) ...{
        'account$i': account,
        if (cursor != null) 'cursorTimestamp$i': cursor.timestamp,
        if (cursor != null) 'cursorId$i': cursor.id,
      },
      if (after.values.any((cursor) => cursor != null)) 'limit': limit,
    };
  }

  /// Reads the answer to [buildIncomingSinceQuery] for the accounts of
  /// [after], in its order.
  ///
  /// Rows of other kinds, such as a mining reward, are passed over: the cursor
  /// moves past them all the same.
  @visibleForTesting
  static Map<String, IncomingSince> incomingSinceOf(Map<String, dynamic> data, Map<String, AccountEventCursor?> after) {
    final read = <String, IncomingSince>{};
    for (final (i, MapEntry(key: account, value: cursor)) in after.entries.indexed) {
      final rows = data[_accountAlias(i)];
      if (rows is! List) {
        throw StateError('account_event response is missing alias ${_accountAlias(i)}: ${data.keys}');
      }
      if (cursor == null) {
        read[account] = IncomingSince(
          received: const [],
          cursor: rows.isEmpty ? _beforeAnyEvent : _cursorOf(rows.single),
        );
        continue;
      }
      final received = <TransactionEvent>[];
      for (final row in rows.cast<Map<String, dynamic>>()) {
        if (row['transfer'] case final Map<String, dynamic> transfer) {
          received.add(_transferEvent(transfer));
        } else if (row['scheduledReversibleTransfer'] case final Map<String, dynamic> scheduled) {
          received.add(ReversibleTransferEvent.fromJson(scheduled, status: ReversibleTransferStatus.SCHEDULED));
        }
      }
      read[account] = IncomingSince(received: received, cursor: rows.isEmpty ? cursor : _cursorOf(rows.last));
    }
    return read;
  }

  /// What each account of [after] received since its cursor there, oldest
  /// first, and the cursor to ask with next. An account with no cursor yet
  /// (null) is only given one, at the end of its history: what it received
  /// before is not answered.
  ///
  /// The cursors are one per account because the indexer adds a block's rows
  /// together and each account is read in one statement: nothing an account
  /// receives lands behind its own cursor. One cursor across accounts could
  /// pass a row that another account's statement ran too early to see.
  Future<Map<String, IncomingSince>> fetchIncomingSince(Map<String, AccountEventCursor?> after) async {
    try {
      final Map<String, dynamic> data = await _graphQlEndpointService.query(
        document: buildIncomingSinceQuery(withCursor: [for (final cursor in after.values) cursor != null]),
        variables: incomingSinceVariables(after, limit: _incomingSincePage),
      );
      return incomingSinceOf(data, after);
    } catch (e, stackTrace) {
      _log('Error fetching what accounts received: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// One `account_event` selection per account, aliased `events0..N-1`, all
  /// sharing `$limit` and the optional cursor.
  static String _accountEventDocument({
    required String operationName,
    required String extraVariables,
    required TransactionFilter filter,
    required bool withCursor,
    required int accountCount,
    required String Function(int index) whereClause,
    required String selection,
  }) {
    final variables =
        '${_accountVariables(accountCount)}, \$limit: Int!$extraVariables${withCursor ? _cursorVariables : ''}';
    final selections = [
      for (var i = 0; i < accountCount; i++)
        '''
  ${_accountAlias(i)}: account_event(limit: \$limit, where: ${whereClause(i)}, ${_accountEventOrder(filter)}) {
$selection
  }''',
    ].join('\n');

    return '''
query $operationName($variables) {
$selections
}
''';
  }

  /// Builds the account-events (other transfers) query for [accountCount]
  /// accounts, one aliased selection per account.
  ///
  /// Every predicate is a plain column on `account_event` so Postgres serves
  /// the page straight from the `(account_id[, outgoing|incoming], timestamp,
  /// id)` index in output order. Send / receive use the indexer-maintained
  /// direction flags; mining rewards are flagged incoming there, so the
  /// `minerReward` selection is only requested when it can appear.
  ///
  /// With [withCursor], the query declares `$cursorTimestamp` / `$cursorId`
  /// and only returns rows strictly after that keyset.
  @visibleForTesting
  static String buildAccountEventsQuery(
    TransactionFilter filter, {
    required bool withCursor,
    required int accountCount,
  }) {
    // Whether to include the minerReward field in the response
    final bool includeMinerReward = filter != TransactionFilter.send;

    final String minerRewardField = includeMinerReward
        ? '''
    minerReward {
      id
      reward
      timestamp
      miner {
        id
      }
      block {
        height
        hash
      }
    }'''
        : '';

    final String multisigField = MultisigGraphql.accountEventSelection;
    final String proposalCreatedField = MultisigGraphql.proposalCreatedAccountEventSelection;
    final String signerApprovedField = MultisigGraphql.signerApprovedAccountEventSelection;
    final String executedProposalField = MultisigGraphql.executedMultisigProposalAccountEventSelection;
    final String cancelledProposalField = MultisigGraphql.cancelledMultisigProposalAccountEventSelection;

    String whereClause(int index) =>
        '{_and: [{account_id: {_eq: \$account$index}}, {scheduled_reversible_transfer_id: {_is_null: true}}'
        '${_directionPredicate(filter)}'
        '${withCursor ? ', $_cursorPredicate' : ''}]}';

    final selection =
        '''
    id
    timestamp
    transfer {
$_transferFields
      executedBy {
        txId: tx_id
      }
    }
    executedReversibleTransfer {
      block {
        height
        hash
      }
      txId: tx_id
      timestamp
      id
      scheduledTransfer {
        amount
        from {
          id
        }
        to {
          id
        }
        scheduledAt: scheduled_at
      }
    }
    cancelledReversibleTransfer {
      block {
        height
        hash
      }
      txId: tx_id
      timestamp
      id
      extrinsic {
        id
      }
      scheduledTransfer {
        amount
        from {
          id
        }
        to {
          id
        }
        scheduledAt: scheduled_at
      }
    }$minerRewardField$multisigField$proposalCreatedField$signerApprovedField$executedProposalField$cancelledProposalField''';

    return _accountEventDocument(
      operationName: 'AccountEvents',
      extraVariables: '',
      filter: filter,
      withCursor: withCursor,
      accountCount: accountCount,
      whereClause: whereClause,
      selection: selection,
    );
  }

  // GraphQL query to fetch transactions by their hash
  final String _executedTransactionByTxId = r'''
query ExecutedReversibleTransferByTxId($txId: String!) {
  executedReversibleTransfers: executed_reversible_transfer(where: {tx_id: {_eq: $txId}}) {
    block {
      height
      hash
    }
    txId: tx_id
    timestamp
    id
    scheduledTransfer {
      amount
      from {
        id
      }
      to {
        id
      }
      scheduledAt: scheduled_at
    }
  }
}
''';

  // GraphQL query to search for transactions matching pending transaction criteria.
  // `extrinsic_isNull: false` excludes mining/wormhole transfers which share the
  // transfer entity but have no extrinsic. Limit is 1 because we only ever use
  // the first match.
  @visibleForTesting
  static const String searchPendingTransferQuery = r'''
query SearchPendingTransaction(
  $from: String!,
  $to: String!,
  $amount: numeric!,
  $blockHeightAfter: Int!,
) {
  events: event(
    limit: 1
    where: {
      transfer: {
        from: { id: {_eq: $from } },
        to: { id: {_eq: $to } },
        amount: {_eq: $amount },
        extrinsic: {id: {_is_null: false}},
        block: {
          height: {_gt: $blockHeightAfter}
        }
      }
    }
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
    extrinsic {
      id
    }
    transfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      block { height hash }
      extrinsic {
        id
        pallet
      }
      timestamp
      fee
    }
  }
}
''';

  @visibleForTesting
  static const String searchPendingReversibleQuery = r'''
query SearchPendingTransaction(
  $from: String!,
  $to: String!,
  $amount: numeric!,
  $blockHeightAfter: Int!,
) {
  events: event(
    limit: 1
    where: {
      scheduledReversibleTransfer: {
        from: { id: {_eq: $from } },
        to: { id: {_eq: $to } },
        amount: {_eq: $amount },
        extrinsic: {id: {_is_null: false}},
        block: {
          height: {_gt: $blockHeightAfter}
        }
      }
    }
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
    extrinsic {
      id
    }
    scheduledReversibleTransfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      txId: tx_id
      scheduledAt: scheduled_at
      block { height hash }
      extrinsic {
        id
      }
      timestamp
    }
  }
}
''';

  @visibleForTesting
  static const String searchByExtrinsicHashTransferQuery = r'''
query SearchByExtrinsicHash($extrinsicHash: String!) {
  events: event(
    limit: 1
    where: { transfer: { extrinsic: { id: {_eq: $extrinsicHash } } } }
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
    extrinsic { id }
    transfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      block { height hash }
      extrinsic { id pallet }
      timestamp
      fee
    }
  }
}
''';

  final String _searchByExtrinsicHashReversibleQuery = r'''
query SearchByExtrinsicHash($extrinsicHash: String!) {
  events: event(
    limit: 1
    where: { scheduledReversibleTransfer: { extrinsic: { id: {_eq: $extrinsicHash } } } }
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
    extrinsic { id }
    scheduledReversibleTransfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      txId: tx_id
      scheduledAt: scheduled_at
      block { height hash }
      extrinsic { id }
      timestamp
    }
  }
}
''';

  final String _searchProposalCreatedByExtrinsicHashQuery =
      '''
query SearchProposalCreatedByExtrinsicHash(\$extrinsicHash: String!) {
  accountEvents: account_event(
    limit: 1
    where: {multisigProposalCreated: {extrinsic: {id: {_eq: \$extrinsicHash}}}}
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
${MultisigGraphql.proposalCreatedAccountEventSelection}
  }
}
''';

  final String _searchSignerApprovedByExtrinsicHashQuery =
      '''
query SearchSignerApprovedByExtrinsicHash(\$extrinsicHash: String!) {
  accountEvents: account_event(
    limit: 1
    where: {multisigSignerApproved: {extrinsic: {id: {_eq: \$extrinsicHash}}}}
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
${MultisigGraphql.signerApprovedAccountEventSelection}
  }
}
''';

  final String _searchExecutedByExtrinsicHashQuery =
      '''
query SearchExecutedByExtrinsicHash(\$extrinsicHash: String!) {
  accountEvents: account_event(
    limit: 1
    where: {executedMultisigProposal: {extrinsic: {id: {_eq: \$extrinsicHash}}}}
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
${MultisigGraphql.executedMultisigProposalAccountEventSelection}
  }
}
''';

  final String _searchCancelledByExtrinsicHashQuery =
      '''
query SearchCancelledByExtrinsicHash(\$extrinsicHash: String!) {
  accountEvents: account_event(
    limit: 1
    where: {cancelledMultisigProposal: {extrinsic: {id: {_eq: \$extrinsicHash}}}}
    order_by: {timestamp: desc}
  ) {
    id
    timestamp
${MultisigGraphql.cancelledMultisigProposalAccountEventSelection}
  }
}
''';

  int _lookaheadLimit(int limit) => limit + 1;

  /// Variables for [buildAccountEventsQuery] / [buildScheduledReversibleTransfersQuery].
  @visibleForTesting
  static Map<String, dynamic> pageVariables({
    required List<String> accountIds,
    required int lookaheadLimit,
    required AccountEventCursor? after,
  }) {
    if (accountIds.isEmpty) {
      throw ArgumentError.value(accountIds, 'accountIds', 'Must not be empty');
    }
    return {
      for (var i = 0; i < accountIds.length; i++) 'account$i': accountIds[i],
      'limit': lookaheadLimit,
      if (after != null) 'cursorTimestamp': after.timestamp,
      if (after != null) 'cursorId': after.id,
    };
  }

  static AccountEventCursor _cursorOf(dynamic row) {
    final map = row as Map<String, dynamic>;
    final timestamp = map['timestamp'];
    final id = map['id'];
    if (timestamp is! String || id is! String) {
      throw StateError('account_event row is missing timestamp/id needed for the keyset cursor: $map');
    }
    return AccountEventCursor(timestamp: timestamp, id: id);
  }

  /// Reassembles the per-account aliases of one response into a single list
  /// in `(timestamp desc, id desc)` order.
  ///
  /// Each alias holds that account's first `limit + 1` rows after the shared
  /// cursor, so the merged head is exactly what one query over all accounts
  /// would have returned; [pageFromRows] then trims it to the page.
  @visibleForTesting
  static List<dynamic> mergeAccountEventRows(Map<String, dynamic> data, {required int accountCount}) {
    final merged = <dynamic>[];
    for (var i = 0; i < accountCount; i++) {
      final rows = data[_accountAlias(i)];
      if (rows is! List) {
        throw StateError('account_event response is missing alias ${_accountAlias(i)}: ${data.keys}');
      }
      merged.addAll(rows);
    }
    if (accountCount == 1) return merged;

    int compare(dynamic a, dynamic b) {
      final cursorA = _cursorOf(a);
      final cursorB = _cursorOf(b);
      final byTime = DateTime.parse(cursorB.timestamp).compareTo(DateTime.parse(cursorA.timestamp));
      return byTime != 0 ? byTime : cursorB.id.compareTo(cursorA.id);
    }

    merged.sort(compare);
    return merged;
  }

  /// Turns the raw `account_event` rows of one lookahead query into a page.
  ///
  /// Up to [limit] rows are consumed; a row past that means [AccountEventPage.hasMore].
  /// The cursor advances to the last consumed row even when it parsed to null,
  /// so skipped rows are never fetched twice. An empty result keeps
  /// [previousCursor] so an exhausted list stays exhausted while the caller
  /// keeps paging its sibling list.
  @visibleForTesting
  static AccountEventPage<T> pageFromRows<T>(
    List<dynamic>? rows,
    int limit,
    T? Function(dynamic row) parseRow, {
    required AccountEventCursor? previousCursor,
  }) {
    if (rows == null || rows.isEmpty) {
      return AccountEventPage(items: <T>[], hasMore: false, nextCursor: previousCursor);
    }

    final hasMore = rows.length > limit;
    final consumed = rows.take(limit).toList();
    final items = <T>[];
    for (final row in consumed) {
      final parsed = parseRow(row);
      if (parsed != null) items.add(parsed);
    }
    return AccountEventPage(items: items, hasMore: hasMore, nextCursor: _cursorOf(consumed.last));
  }

  ReversibleTransferEvent _parseScheduledTransferEvent(dynamic event) {
    final eventMap = event as Map<String, dynamic>;
    final scheduledTransfer = eventMap['scheduledReversibleTransfer'];
    if (scheduledTransfer == null) {
      throw Exception('Scheduled account event is missing scheduledReversibleTransfer: ${eventMap['id']}');
    }
    return ReversibleTransferEvent.fromJson(scheduledTransfer, status: ReversibleTransferStatus.SCHEDULED);
  }

  /// Parses a transfer-style [account_event]. Returns null for unsupported payloads
  /// (e.g. multisig creation) so history fetching can continue.
  TransactionEvent? tryParseOtherTransferEvent(dynamic event) {
    final eventMap = event as Map<String, dynamic>;
    if (eventMap['cancelledReversibleTransfer'] != null) {
      return ReversibleTransferEvent.fromJson(
        eventMap['cancelledReversibleTransfer'],
        status: ReversibleTransferStatus.CANCELLED,
      );
    }
    if (eventMap['executedReversibleTransfer'] != null) {
      return ReversibleTransferEvent.fromJson(
        eventMap['executedReversibleTransfer'],
        status: ReversibleTransferStatus.EXECUTED,
      );
    }
    if (eventMap['transfer'] != null) {
      return _transferEvent(eventMap['transfer'] as Map<String, dynamic>);
    }
    if (eventMap['minerReward'] != null) {
      return MinerRewardEvent.fromJson(eventMap['minerReward']);
    }
    if (eventMap['multisig'] != null) {
      return _tryParseMultisigEvent(eventMap, 'multisig', MultisigCreatedEvent.fromAccountEvent);
    }
    if (eventMap['multisigProposalCreated'] != null) {
      return _tryParseMultisigEvent(eventMap, 'multisigProposalCreated', MultisigProposalCreatedEvent.fromAccountEvent);
    }
    if (eventMap['multisigSignerApproved'] != null) {
      return _tryParseMultisigEvent(eventMap, 'multisigSignerApproved', MultisigProposalApprovedEvent.fromAccountEvent);
    }
    if (eventMap['executedMultisigProposal'] != null) {
      return _tryParseMultisigEvent(
        eventMap,
        'executedMultisigProposal',
        MultisigProposalExecutedEvent.fromAccountEvent,
      );
    }
    if (eventMap['cancelledMultisigProposal'] != null) {
      return _tryParseMultisigEvent(
        eventMap,
        'cancelledMultisigProposal',
        MultisigProposalCancelledEvent.fromAccountEvent,
      );
    }
    final id = eventMap['id'] as String?;
    if (id != null && _isSkippedMultisigAccountEventId(id)) {
      // Known multisig-related rows we don't render in activity yet.
      return null;
    }
    // An unexpected payload likely signals an indexer/schema regression, so
    // flag it loudly rather than dropping it silently.
    _log('WARNING: unsupported account event payload, id: $id');
    return null;
  }

  /// Parses a multisig account event, degrading a malformed row to a logged
  /// skip so one bad record cannot fail the whole history page.
  TransactionEvent? _tryParseMultisigEvent(
    Map<String, dynamic> eventMap,
    String label,
    TransactionEvent Function(Map<String, dynamic>) parse,
  ) {
    try {
      return parse(eventMap);
    } catch (e, stackTrace) {
      _log('WARNING: failed to parse $label, id: ${eventMap['id']}, error: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Other multisig-related indexer rows (approvals, deposits claimed, etc.)
  /// are not shown in activity yet.
  static bool _isSkippedMultisigAccountEventId(String id) {
    if (id.startsWith('ae-ms-proposal-created-')) return false;
    if (id.startsWith('ae-ms-signer-approved-')) return false;
    if (id.startsWith('ae-ms-exec-')) return false;
    // No trailing dash on purpose: covers both 'ae-ms-cancel-' and
    // 'ae-ms-cancelled-' id variants.
    if (id.startsWith('ae-ms-cancel')) return false;
    return id.startsWith('ae-multisig-') || id.startsWith('ae-ms-');
  }

  // Make a graphQL query for specific transaction hashes, get the results back
  // Mostly to check if reversibles have been executed or failed.
  Future<ReversibleTransferEvent?> fetchExecutedTransactionByTxId({required String txId}) async {
    if (txId.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> data = await _graphQlEndpointService.query(
        document: _executedTransactionByTxId,
        variables: {'txId': txId},
      );

      final List<dynamic>? events = data['executedReversibleTransfers'];

      if (events == null || events.isEmpty) {
        _log('No transaction found for txId: $txId');
        return null;
      }

      final transaction = ReversibleTransferEvent.fromJson(events.first, status: ReversibleTransferStatus.EXECUTED);

      return transaction;
    } catch (e, stackTrace) {
      _log('Error fetching transactions by tx id: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<AccountEventPage<ReversibleTransferEvent>> _fetchScheduledReversibleTransfersPage({
    required List<String> accountIds,
    int limit = 10,
    AccountEventCursor? after,
    required TransactionFilter filter,
  }) async {
    final pendingSince = DateTime.now().subtract(const Duration(minutes: 2)).toUtc().toIso8601String();

    final sw = Stopwatch()..start();
    try {
      final Map<String, dynamic> data = await _graphQlEndpointService.query(
        document: buildScheduledReversibleTransfersQuery(
          filter,
          withCursor: after != null,
          accountCount: accountIds.length,
        ),
        variables: {
          ...pageVariables(accountIds: accountIds, lookaheadLimit: _lookaheadLimit(limit), after: after),
          'after': pendingSince,
        },
      );
      sw.stop();
      printTiming('fetchScheduledTransfers HTTP', sw.elapsedMilliseconds);

      final events = mergeAccountEventRows(data, accountCount: accountIds.length);
      return pageFromRows(events, limit, _parseScheduledTransferEvent, previousCursor: after);
    } catch (e, stackTrace) {
      sw.stop();
      printTiming('fetchScheduledTransfers FAILED', sw.elapsedMilliseconds);
      _log('Error fetching scheduled transfers: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Fetches one page of non-scheduled history for [accountIds], starting
  /// strictly after [after] (or from the newest row when null).
  Future<OtherTransfersResult> fetchOtherTransfers({
    required List<String> accountIds,
    int limit = 10,
    AccountEventCursor? after,
    required TransactionFilter filter,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final Map<String, dynamic> data = await _graphQlEndpointService.query(
        document: buildAccountEventsQuery(filter, withCursor: after != null, accountCount: accountIds.length),
        variables: pageVariables(accountIds: accountIds, lookaheadLimit: _lookaheadLimit(limit), after: after),
      );
      sw.stop();
      printTiming('fetchAccountEvents HTTP', sw.elapsedMilliseconds);

      final events = mergeAccountEventRows(data, accountCount: accountIds.length);
      final page = pageFromRows(events, limit, tryParseOtherTransferEvent, previousCursor: after);
      return OtherTransfersResult(transfers: page.items, hasMore: page.hasMore, nextCursor: page.nextCursor);
    } catch (e, stackTrace) {
      sw.stop();
      printTiming('fetchOtherTransfers FAILED', sw.elapsedMilliseconds);
      _log('Error fetching other transfers: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Fetches the next page of both history lists. [otherAfter] and
  /// [scheduledAfter] are the cursors returned by the previous call; leave them
  /// null for the first page.
  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    AccountEventCursor? otherAfter,
    AccountEventCursor? scheduledAfter,
    required TransactionFilter filter,
  }) async {
    try {
      final results = await Future.wait([
        _fetchScheduledReversibleTransfersPage(
          accountIds: accountIds,
          limit: limit,
          after: scheduledAfter,
          filter: filter,
        ),
        fetchOtherTransfers(accountIds: accountIds, limit: limit, after: otherAfter, filter: filter),
      ]);

      final scheduledReversibleTransfers = results[0] as AccountEventPage<ReversibleTransferEvent>;
      final otherTransfers = results[1] as OtherTransfersResult;

      return SortedTransactionsList(
        scheduledReversibleTransfers: scheduledReversibleTransfers.items,
        otherTransfers: otherTransfers.transfers,
        nextOtherCursor: otherTransfers.nextCursor,
        nextScheduledCursor: scheduledReversibleTransfers.nextCursor,
        hasMore: scheduledReversibleTransfers.hasMore || otherTransfers.hasMore,
      );
    } catch (e, stackTrace) {
      _log('Error fetching all transaction types: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Searches for transactions matching the criteria of a pending transaction.
  /// This is used to find if a broadcast transaction has been confirmed.
  /// Searches both transfer and reversibleTransfer types. Excludes mining and
  /// wormhole transfers (no extrinsic).
  Future<TransactionEvent?> searchForPendingTransaction({
    required String from,
    required String to,
    required BigInt amount,
    required bool isReversible,
    required int blockHeightAfter,
  }) {
    _log(
      'Searching for pending transaction: $from → $to, amount: $amount, '
      'reversible: $isReversible, after block: $blockHeightAfter',
    );
    return _searchEvent(
      query: isReversible ? searchPendingReversibleQuery : searchPendingTransferQuery,
      variables: {'from': from, 'to': to, 'amount': amount.toString(), 'blockHeightAfter': blockHeightAfter},
      isReversible: isReversible,
    );
  }

  /// Searches for a transaction by its extrinsic hash. Preferred over
  /// [searchForPendingTransaction] because the extrinsic hash is globally
  /// unique — no risk of matching an unrelated historical transfer with the
  /// same (from, to, amount).
  Future<TransactionEvent?> searchByExtrinsicHash({required String extrinsicHash, required bool isReversible}) {
    _log('Searching by extrinsic hash: $extrinsicHash, reversible: $isReversible');
    return _searchEvent(
      query: isReversible ? _searchByExtrinsicHashReversibleQuery : searchByExtrinsicHashTransferQuery,
      variables: {'extrinsicHash': extrinsicHash},
      isReversible: isReversible,
    );
  }

  /// Searches for a confirmed multisig proposal approval by extrinsic hash.
  Future<MultisigProposalApprovedEvent?> searchSignerApprovedByExtrinsicHash({required String extrinsicHash}) {
    return _searchAccountEventByExtrinsicHash<MultisigProposalApprovedEvent>(
      query: _searchSignerApprovedByExtrinsicHashQuery,
      extrinsicHash: extrinsicHash,
      description: 'signer approval',
    );
  }

  /// Searches for a confirmed multisig proposal execution by extrinsic hash.
  Future<MultisigProposalExecutedEvent?> searchExecutedByExtrinsicHash({required String extrinsicHash}) {
    return _searchAccountEventByExtrinsicHash<MultisigProposalExecutedEvent>(
      query: _searchExecutedByExtrinsicHashQuery,
      extrinsicHash: extrinsicHash,
      description: 'proposal execution',
    );
  }

  /// Searches for a confirmed multisig proposal cancellation by extrinsic hash.
  Future<MultisigProposalCancelledEvent?> searchCancelledByExtrinsicHash({required String extrinsicHash}) {
    return _searchAccountEventByExtrinsicHash<MultisigProposalCancelledEvent>(
      query: _searchCancelledByExtrinsicHashQuery,
      extrinsicHash: extrinsicHash,
      description: 'proposal cancellation',
    );
  }

  /// Searches for a confirmed multisig proposal creation by extrinsic hash.
  Future<MultisigProposalCreatedEvent?> searchProposalCreatedByExtrinsicHash({required String extrinsicHash}) {
    return _searchAccountEventByExtrinsicHash<MultisigProposalCreatedEvent>(
      query: _searchProposalCreatedByExtrinsicHashQuery,
      extrinsicHash: extrinsicHash,
      description: 'proposal creation',
    );
  }

  /// Runs [query] against `account_event` filtered by extrinsic hash and
  /// returns the parsed event when it is a [T].
  ///
  /// [description] is a human-readable name for log messages, e.g.
  /// `'proposal cancellation'`.
  Future<T?> _searchAccountEventByExtrinsicHash<T extends TransactionEvent>({
    required String query,
    required String extrinsicHash,
    required String description,
  }) async {
    _log('Searching $description by extrinsic hash: $extrinsicHash');
    try {
      final Map<String, dynamic> data = await _graphQlEndpointService.query(
        document: query,
        variables: {'extrinsicHash': extrinsicHash},
      );

      final List<dynamic>? events = data['accountEvents'];
      if (events == null || events.isEmpty) {
        _log('No matching $description found for hash $extrinsicHash');
        return null;
      }

      final parsed = tryParseOtherTransferEvent(events.first);
      if (parsed is T) {
        _log('Found $description at block ${parsed.blockNumber}');
        return parsed;
      }

      _log('Extrinsic hash matched account_event but payload was not $T');
      return null;
    } catch (e, stackTrace) {
      _log('Error searching $description by hash: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// A transfer the wormhole pallet paid out is the receipt of a private send.
  static TransactionEvent _transferEvent(Map<String, dynamic> json) {
    final transfer = TransferEvent.fromJson(json);
    return jsonMapOrNull(json['extrinsic'])?['pallet'] == wormholePallet
        ? WormholeTransferEvent.receipt(transfer)
        : transfer;
  }

  Future<TransactionEvent?> _searchEvent({
    required String query,
    required Map<String, dynamic> variables,
    required bool isReversible,
  }) async {
    try {
      final Map<String, dynamic> data = await _graphQlEndpointService.query(document: query, variables: variables);

      final List<dynamic>? events = data['events'];

      if (events == null || events.isEmpty) {
        _log('No matching transactions found');
        return null;
      }

      final eventJson = events.first!;
      final TransactionEvent transaction;
      if (isReversible) {
        final reversibleTransferData = eventJson['scheduledReversibleTransfer'] as Map<String, dynamic>;
        transaction = ReversibleTransferEvent.fromJson(
          reversibleTransferData,
          status: ReversibleTransferStatus.SCHEDULED,
        );
      } else {
        transaction = _transferEvent(eventJson['transfer'] as Map<String, dynamic>);
      }

      _log('Found matching transaction at block ${transaction.blockNumber}');
      return transaction;
    } catch (e, stackTrace) {
      _log('Error searching for transaction: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
