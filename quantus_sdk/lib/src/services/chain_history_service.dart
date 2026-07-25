import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/services/multisig_graphql.dart';
import 'package:quantus_sdk/src/utils/timing.dart';

class OtherTransfersResult {
  final List<TransactionEvent> transfers;
  final bool hasMore;

  /// The number of raw rows consumed from the query result, including skipped
  /// rows. Use this to advance pagination cursors, not [transfers.length].
  final int rawRowsConsumed;

  const OtherTransfersResult({required this.transfers, required this.hasMore, required this.rawRowsConsumed});
}

class _Page<T> {
  final List<T> items;
  final bool hasMore;

  /// The number of raw rows consumed from the query result, including rows
  /// that parsed to null. Use this to advance pagination cursors.
  final int rawRowsConsumed;

  const _Page({required this.items, required this.hasMore, required this.rawRowsConsumed});
}

class ChainHistoryService {
  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();

  static const _logName = 'ChainHistoryService';

  ChainHistoryService();

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: _logName, error: error, stackTrace: stackTrace);
  }

  String _buildScheduledReversibleTransfersQuery(TransactionFilter filter) {
    final String whereClause;

    switch (filter) {
      case TransactionFilter.send:
        whereClause =
            '{_and: [{account_id: {_in: \$accounts}}, {scheduled_reversible_transfer_id: {_is_null: false}}, {scheduledReversibleTransfer: {from_id: {_in: \$accounts}, scheduled_at: {_gt: \$after}}}]}';
        break;
      case TransactionFilter.receive:
        whereClause =
            '{_and: [{account_id: {_in: \$accounts}}, {scheduled_reversible_transfer_id: {_is_null: false}}, {scheduledReversibleTransfer: {to_id: {_in: \$accounts}, scheduled_at: {_gt: \$after}}}]}';
        break;
      case TransactionFilter.all:
        whereClause =
            '{_and: [{account_id: {_in: \$accounts}}, {scheduled_reversible_transfer_id: {_is_null: false}}, {scheduledReversibleTransfer: {scheduled_at: {_gt: \$after}}}]}';
        break;
    }

    return '''
query ScheduledReversibleTransfersByAccounts(\$accounts: [String!]!, \$limit: Int!, \$offset: Int!, \$after: timestamptz!) {
  accountEvents: account_event(
    limit: \$limit, 
    offset: \$offset, 
    where: $whereClause, 
    order_by: {timestamp: desc}
  ) {
    id
    scheduledReversibleTransfer {
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
      }
    }
  }
}
''';
  }

  /// Builds the account-events (other transfers) query.
  ///
  /// When [filter] is [TransactionFilter.send] or [TransactionFilter.receive],
  /// a direction-specific condition is injected so the database only returns
  /// matching rows instead of filtering client-side.
  ///
  /// Mining rewards are always a "receive", so they are excluded when the
  /// filter is [TransactionFilter.send] and included otherwise.
  String _buildAccountEventsQuery(TransactionFilter filter) {
    // The base condition that applies to every variant.
    // Using Hasura's direct foreign key field is cleaner.
    const String baseCondition = '{scheduled_reversible_transfer_id: {_is_null: true}}';

    // Transfer extrinsic guard — only include on-chain transfers.
    // Using direct `transfer_id` and `extrinsic_id` relation fields.
    const String transferGuard =
        '{_or: [{transfer_id: {_is_null: true}}, {transfer: {extrinsic_id: {_is_null: false}}}]}';

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

    const String multisigSendClause =
        ', {multisig_id: {_is_null: false}}, {multisig_proposal_created_id: {_is_null: false}}, {multisig_signer_approved_id: {_is_null: false}}, {executed_multisig_proposal_id: {_is_null: false}}, {cancelled_multisig_proposal_id: {_is_null: false}}';

    final String whereClause;

    switch (filter) {
      case TransactionFilter.send:
        whereClause =
            '{_and: [{account_id: {_in: \$accounts}}, $baseCondition, $transferGuard, {_or: [{transfer: {from_id: {_in: \$accounts}}}, {executedReversibleTransfer: {scheduledTransfer: {from_id: {_in: \$accounts}}}}, {cancelledReversibleTransfer: {scheduledTransfer: {from_id: {_in: \$accounts}}}}$multisigSendClause]}]}';
        break;
      case TransactionFilter.receive:
        whereClause =
            '{_and: [{account_id: {_in: \$accounts}}, $baseCondition, $transferGuard, {_or: [{transfer: {to_id: {_in: \$accounts}}}, {executedReversibleTransfer: {scheduledTransfer: {to_id: {_in: \$accounts}}}}, {cancelledReversibleTransfer: {scheduledTransfer: {to_id: {_in: \$accounts}}}}, {miner_reward_id: {_is_null: false}}]}]}';
        break;
      case TransactionFilter.all:
        whereClause = '{_and: [{account_id: {_in: \$accounts}}, $baseCondition, $transferGuard]}';
        break;
    }

    return '''
query AccountEvents(\$accounts: [String!]!, \$limit: Int!, \$offset: Int!) {
  accountEvents: account_event(limit: \$limit, offset: \$offset, where: $whereClause, order_by: {timestamp: desc}) {
    id
    timestamp
    transfer {
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
      }
      fee
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
    }$minerRewardField$multisigField$proposalCreatedField$signerApprovedField$executedProposalField$cancelledProposalField
  }
}
''';
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
  final String _searchPendingTransferQuery = r'''
query SearchPendingTransaction(
  $from: String!,
  $to: String!,
  $amount: BigInt!,
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
      }
      timestamp
      fee
    }
  }
}
''';

  final String _searchPendingReversibleQuery = r'''
query SearchPendingTransaction(
  $from: String!,
  $to: String!,
  $amount: BigInt!,
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

  final String _searchByExtrinsicHashTransferQuery = r'''
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
      extrinsic { id }
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

  _Page<T> _pageFromEvents<T>(List<dynamic>? events, int limit, T? Function(dynamic event) parseEvent) {
    if (events == null || events.isEmpty) {
      return _Page(items: <T>[], hasMore: false, rawRowsConsumed: 0);
    }

    // hasMore is true if the query returned more rows than requested (lookahead).
    final hasMore = events.length > limit;
    final items = <T>[];
    var rawRowsConsumed = 0;
    for (final event in events) {
      // Stop once we have enough parsed items, but track all consumed rows.
      if (items.length >= limit) break;
      rawRowsConsumed++;
      final parsed = parseEvent(event);
      if (parsed != null) items.add(parsed);
    }
    return _Page(items: items, hasMore: hasMore, rawRowsConsumed: rawRowsConsumed);
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
      return TransferEvent.fromJson(eventMap['transfer']);
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

    final Map<String, dynamic> requestBody = {
      'query': _executedTransactionByTxId,
      'variables': {'txId': txId},
    };

    try {
      final http.Response response = await _graphQlEndpointService.post(body: jsonEncode(requestBody));

      if (response.statusCode != 200) {
        throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (responseBody['errors'] != null) {
        _log('GraphQL errors in response: ${responseBody['errors']}');
        throw Exception('GraphQL errors: ${responseBody['errors'].toString()}');
      }

      final Map<String, dynamic>? data = responseBody['data'];
      if (data == null) {
        throw Exception('GraphQL response data is null.');
      }

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

  Future<_Page<ReversibleTransferEvent>> _fetchScheduledReversibleTransfersPage({
    required List<String> accountIds,
    int limit = 10,
    int offset = 0,
    required TransactionFilter filter,
  }) async {
    final after = DateTime.now().subtract(const Duration(minutes: 2)).toUtc().toIso8601String();

    final Map<String, dynamic> requestBody = {
      'query': _buildScheduledReversibleTransfersQuery(filter),
      'variables': {'accounts': accountIds, 'limit': _lookaheadLimit(limit), 'offset': offset, 'after': after},
    };

    final jsonBody = jsonEncode(requestBody);

    final sw = Stopwatch()..start();
    try {
      final http.Response response = await _graphQlEndpointService.post(body: jsonBody);
      sw.stop();
      printTiming('fetchScheduledTransfers HTTP', sw.elapsedMilliseconds);

      if (response.statusCode != 200) {
        throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['errors'] != null) {
        throw Exception('GraphQL errors: ${responseBody['errors']}');
      }

      final List<dynamic>? events = responseBody['data']?['accountEvents'];
      return _pageFromEvents(events, limit, _parseScheduledTransferEvent);
    } catch (e, stackTrace) {
      sw.stop();
      printTiming('fetchScheduledTransfers FAILED', sw.elapsedMilliseconds);
      _log('Error fetching scheduled transfers: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<OtherTransfersResult> fetchOtherTransfers({
    required List<String> accountIds,
    int limit = 10,
    int offset = 0,
    required TransactionFilter filter,
  }) async {
    final Map<String, dynamic> requestBody = {
      'query': _buildAccountEventsQuery(filter),
      'variables': {'accounts': accountIds, 'limit': _lookaheadLimit(limit), 'offset': offset},
    };

    final jsonBody = jsonEncode(requestBody);

    final sw = Stopwatch()..start();
    try {
      final http.Response response = await _graphQlEndpointService.post(body: jsonBody);
      sw.stop();
      printTiming('fetchAccountEvents HTTP', sw.elapsedMilliseconds);

      if (response.statusCode != 200) {
        throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['errors'] != null) {
        throw Exception('GraphQL errors: ${responseBody['errors']}');
      }

      final List<dynamic>? events = responseBody['data']?['accountEvents'];
      final page = _pageFromEvents(events, limit, tryParseOtherTransferEvent);
      return OtherTransfersResult(transfers: page.items, hasMore: page.hasMore, rawRowsConsumed: page.rawRowsConsumed);
    } catch (e, stackTrace) {
      sw.stop();
      printTiming('fetchOtherTransfers FAILED', sw.elapsedMilliseconds);
      _log('Error fetching other transfers: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    int otherOffset = 0,
    int scheduledOffset = 0,
    required TransactionFilter filter,
  }) async {
    try {
      final results = await Future.wait([
        _fetchScheduledReversibleTransfersPage(
          accountIds: accountIds,
          limit: limit,
          offset: scheduledOffset,
          filter: filter,
        ),
        fetchOtherTransfers(accountIds: accountIds, limit: limit, offset: otherOffset, filter: filter),
      ]);

      final scheduledReversibleTransfers = results[0] as _Page<ReversibleTransferEvent>;
      final otherTransfers = results[1] as OtherTransfersResult;

      // Advance offsets by raw rows consumed, not parsed item count, so the
      // cursor doesn't drift when rows are skipped (null-parsed).
      final nextOtherOffset = otherOffset + otherTransfers.rawRowsConsumed;
      final nextScheduledOffset = scheduledOffset + scheduledReversibleTransfers.rawRowsConsumed;

      return SortedTransactionsList(
        scheduledReversibleTransfers: scheduledReversibleTransfers.items,
        otherTransfers: otherTransfers.transfers,
        nextOtherOffset: nextOtherOffset,
        nextScheduledOffset: nextScheduledOffset,
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
      query: isReversible ? _searchPendingReversibleQuery : _searchPendingTransferQuery,
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
      query: isReversible ? _searchByExtrinsicHashReversibleQuery : _searchByExtrinsicHashTransferQuery,
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
    final Map<String, dynamic> requestBody = {
      'query': query,
      'variables': {'extrinsicHash': extrinsicHash},
    };

    try {
      final http.Response response = await _graphQlEndpointService.post(body: jsonEncode(requestBody));

      if (response.statusCode != 200) {
        throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (responseBody['errors'] != null) {
        _log('GraphQL errors in response: ${responseBody['errors']}');
        throw Exception('GraphQL errors: ${responseBody['errors'].toString()}');
      }

      final List<dynamic>? events = responseBody['data']?['accountEvents'];
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

  Future<TransactionEvent?> _searchEvent({
    required String query,
    required Map<String, dynamic> variables,
    required bool isReversible,
  }) async {
    final Map<String, dynamic> requestBody = {'query': query, 'variables': variables};

    try {
      final http.Response response = await _graphQlEndpointService.post(body: jsonEncode(requestBody));

      if (response.statusCode != 200) {
        throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (responseBody['errors'] != null) {
        _log('GraphQL errors in response: ${responseBody['errors']}');
        throw Exception('GraphQL errors: ${responseBody['errors'].toString()}');
      }

      final Map<String, dynamic>? data = responseBody['data'];
      if (data == null) {
        throw Exception('GraphQL response data is null.');
      }

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
        final transferData = eventJson['transfer'] as Map<String, dynamic>;
        transaction = TransferEvent.fromJson(transferData);
      }

      _log('Found matching transaction at block ${transaction.blockNumber}');
      return transaction;
    } catch (e, stackTrace) {
      _log('Error searching for transaction: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
