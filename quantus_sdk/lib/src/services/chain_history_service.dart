import 'dart:convert'; // Required for jsonEncode and jsonDecode

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/utils/timing.dart';

class OtherTransfersResult {
  final List<TransactionEvent> transfers;
  final bool hasMore;

  const OtherTransfersResult({required this.transfers, required this.hasMore});
}

class _Page<T> {
  final List<T> items;
  final bool hasMore;

  const _Page({required this.items, required this.hasMore});
}

class ChainHistoryService {
  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();

  ChainHistoryService();

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

    final String whereClause;

    switch (filter) {
      case TransactionFilter.send:
        // Properly formatted Hasura boolean expression with colons and balanced brackets
        whereClause =
            '{_and: [{account_id: {_in: \$accounts}}, $baseCondition, $transferGuard, {_or: [{transfer: {from_id: {_in: \$accounts}}}, {executedReversibleTransfer: {scheduledTransfer: {from_id: {_in: \$accounts}}}}, {cancelledReversibleTransfer: {scheduledTransfer: {from_id: {_in: \$accounts}}}}]}]}';
        break;
      case TransactionFilter.receive:
        // Properly formatted Hasura boolean expression with colons and balanced brackets
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
    }$minerRewardField
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

  int _lookaheadLimit(int limit) => limit + 1;

  _Page<T> _pageFromEvents<T>(List<dynamic>? events, int limit, T Function(dynamic event) parseEvent) {
    if (events == null || events.isEmpty) {
      return _Page(items: <T>[], hasMore: false);
    }

    return _Page(items: events.take(limit).map(parseEvent).toList(), hasMore: events.length > limit);
  }

  ReversibleTransferEvent _parseScheduledTransferEvent(dynamic event) {
    final eventMap = event as Map<String, dynamic>;
    final scheduledTransfer = eventMap['scheduledReversibleTransfer'];
    if (scheduledTransfer == null) {
      throw Exception('Scheduled account event is missing scheduledReversibleTransfer: ${eventMap['id']}');
    }
    return ReversibleTransferEvent.fromJson(scheduledTransfer, status: ReversibleTransferStatus.SCHEDULED);
  }

  TransactionEvent _parseOtherTransferEvent(dynamic event) {
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
    throw Exception('Account event is missing a supported transaction payload: ${eventMap['id']}');
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
        print('GraphQL errors in response: ${responseBody['errors']}');
        throw Exception('GraphQL errors: ${responseBody['errors'].toString()}');
      }

      final Map<String, dynamic>? data = responseBody['data'];
      if (data == null) {
        throw Exception('GraphQL response data is null.');
      }

      final List<dynamic>? events = data['executedReversibleTransfers'];

      if (events == null || events.isEmpty) {
        print('No transaction found for txId: $txId');
        return null;
      }

      final transaction = ReversibleTransferEvent.fromJson(events.first, status: ReversibleTransferStatus.EXECUTED);

      return transaction;
    } catch (e, stackTrace) {
      print('Error fetching transactions by tx id: $e');
      print(stackTrace);
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
      print('Error fetching scheduled transfers: $e');
      print(stackTrace);
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
      print('events: $events');
      final page = _pageFromEvents(events, limit, _parseOtherTransferEvent);
      return OtherTransfersResult(transfers: page.items, hasMore: page.hasMore);
    } catch (e, stackTrace) {
      sw.stop();
      printTiming('fetchOtherTransfers FAILED', sw.elapsedMilliseconds);
      print('Error fetching other transfers: $e');
      print(stackTrace);
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

      final nextOtherOffset = otherOffset + otherTransfers.transfers.length;
      final nextScheduledOffset = scheduledOffset + scheduledReversibleTransfers.items.length;

      return SortedTransactionsList(
        scheduledReversibleTransfers: scheduledReversibleTransfers.items,
        otherTransfers: otherTransfers.transfers,
        nextOtherOffset: nextOtherOffset,
        nextScheduledOffset: nextScheduledOffset,
        hasMore: scheduledReversibleTransfers.hasMore || otherTransfers.hasMore,
      );
    } catch (e, stackTrace) {
      print('Error fetching all transaction types: $e');
      print(stackTrace);
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
    print(
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
    print('Searching by extrinsic hash: $extrinsicHash, reversible: $isReversible');
    return _searchEvent(
      query: isReversible ? _searchByExtrinsicHashReversibleQuery : _searchByExtrinsicHashTransferQuery,
      variables: {'extrinsicHash': extrinsicHash},
      isReversible: isReversible,
    );
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
        print('GraphQL errors in response: ${responseBody['errors']}');
        throw Exception('GraphQL errors: ${responseBody['errors'].toString()}');
      }

      final Map<String, dynamic>? data = responseBody['data'];
      if (data == null) {
        throw Exception('GraphQL response data is null.');
      }

      final List<dynamic>? events = data['events'];

      if (events == null || events.isEmpty) {
        print('No matching transactions found');
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

      print('Found matching transaction at block ${transaction.blockNumber}');
      return transaction;
    } catch (e, stackTrace) {
      print('Error searching for transaction: $e');
      print(stackTrace);
      rethrow;
    }
  }
}
