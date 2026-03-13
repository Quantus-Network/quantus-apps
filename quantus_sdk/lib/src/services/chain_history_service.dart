import 'dart:convert'; // Required for jsonEncode and jsonDecode

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';

class OtherTransfersResult {
  final List<TransactionEvent> transfers;
  final int totalCount;

  OtherTransfersResult({required this.transfers, required this.totalCount});
}

class ChainHistoryService {
  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();

  // We don't need a client instance anymore, just the endpoint
  ChainHistoryService();

  final String _scheduledReversibleTransfersQuery = r'''
query ScheduledReversibleTransfersByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!, $after: DateTime!) {
  accountEvents(limit: $limit, 
    offset: $offset, 
    where: {
      account: {id_in: $accounts},
      scheduledReversibleTransfer_isNull: false,
      scheduledReversibleTransfer: {scheduledAt_gt: $after}
    }, orderBy: timestamp_DESC
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
      txId
      scheduledAt
      block {
        height
        hash
      }
      extrinsicHash
      timestamp
    }
  }
}
''';

  final String _accountEventsQuery = r'''
query AccountEvents($accounts: [String!]!, $limit: Int!, $offset: Int!) {
  accountEvents(limit: $limit, offset: $offset, where: {AND: [{account: {id_in: $accounts}, balanceEvent_isNull: true, scheduledReversibleTransfer_isNull: true}, {OR: [{transfer_isNull: true}, {transfer: {extrinsicHash_isNull: false}}]}]}, orderBy: timestamp_DESC) {
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
      extrinsicHash
      timestamp
      fee
      executedBy {
        txId
      }
    }
    executedReversibleTransfer {
      block {
        height
        hash
      }
      txId
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
        scheduledAt
      }
    }
    cancelledReversibleTransfer {
      block {
        height
        hash
      }
      txId
      timestamp
      id
      extrinsicHash
      scheduledTransfer {
        amount
        from {
          id
        }
        to {
          id
        }
        scheduledAt
      }
    }
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
    }
  }
  accountEventsConnection(orderBy: id_ASC, where: {AND: [{account: {id_in: $accounts}, balanceEvent_isNull: true, scheduledReversibleTransfer_isNull: true}, {OR: [{transfer_isNull: true}, {transfer: {extrinsicHash_isNull: false}}]}]}) {
    totalCount
  }
}
''';

  // GraphQL query to fetch transactions by their hash
  final String _executedTransactionByTxId = r'''
query ExecutedReversibleTransferByTxId($txId: String!) {
  executedReversibleTransfers(where: {txId_eq: $txId}) {
    block {
      height
      hash
    }
    txId
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
      scheduledAt
    }
  }
}
''';

  // GraphQL query to search for transactions matching pending transaction criteria
  final String _searchPendingTransferQuery = r'''
query SearchPendingTransaction(
  $from: String!,
  $to: String!,
  $amount: BigInt!,
  $blockHeightAfter: Int!,
  $limit: Int!
) {
  events(
    limit: $limit
    where: {
      transfer: {
        from: { id_eq: $from },
        to: { id_eq: $to },
        amount_eq: $amount,
        block: {
          height_gt: $blockHeightAfter
        }
      }
    }
    orderBy: timestamp_DESC
  ) {
    id
    timestamp
    extrinsicHash
    transfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      block { height hash }
      extrinsicHash
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
  $limit: Int!
) {
  events(
    limit: $limit
    where: {   
      scheduledReversibleTransfer: {
        from: { id_eq: $from },
        to: { id_eq: $to },
        amount_eq: $amount,
        block: {
          height_gt: $blockHeightAfter
        }
      }
    }
    orderBy: timestamp_DESC
  ) {
    id
    timestamp
    extrinsicHash
    scheduledReversibleTransfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      txId
      scheduledAt
      block { height hash }
      extrinsicHash
      timestamp
    }
  }
}
''';

  void printTiming(String label, int milliseconds) {
    if (AppConstants.debugQueryTiming) {
      print('[TIMING] $label: $milliseconds ms');
    }
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

  Future<List<ReversibleTransferEvent>> fetchScheduledReversibleTransfers({
    required List<String> accountIds,
    int limit = 10,
    int offset = 0,
  }) async {
    final after = DateTime.now().subtract(const Duration(minutes: 2)).toUtc().toIso8601String();

    final Map<String, dynamic> requestBody = {
      'query': _scheduledReversibleTransfersQuery,
      'variables': {'accounts': accountIds, 'limit': limit, 'offset': offset, 'after': after},
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
      if (events == null) {
        return [];
      }

      final result = events
          .map(
            (event) => ReversibleTransferEvent.fromJson(
              event['scheduledReversibleTransfer'],
              status: ReversibleTransferStatus.SCHEDULED,
            ),
          )
          .toList();

      return result;
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
  }) async {
    final Map<String, dynamic> requestBody = {
      'query': _accountEventsQuery,
      'variables': {'accounts': accountIds, 'limit': limit, 'offset': offset},
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
      final int totalCount = responseBody['data']?['accountEventsConnection']?['totalCount'] ?? 0;

      if (events == null || totalCount == 0) {
        return OtherTransfersResult(transfers: [], totalCount: 0);
      }

      final List<TransactionEvent> otherTransfers = [];

      for (var event in events) {
        if (event['cancelledReversibleTransfer'] != null) {
          final cancelledReversibleTransfer = ReversibleTransferEvent.fromJson(
            event['cancelledReversibleTransfer'],
            status: ReversibleTransferStatus.CANCELLED,
          );

          otherTransfers.add(cancelledReversibleTransfer);
        } else if (event['executedReversibleTransfer'] != null) {
          final executedReversibleTransfer = ReversibleTransferEvent.fromJson(
            event['executedReversibleTransfer'],
            status: ReversibleTransferStatus.EXECUTED,
          );

          otherTransfers.add(executedReversibleTransfer);
        } else if (event['transfer'] != null) {
          otherTransfers.add(TransferEvent.fromJson(event['transfer']));
        } else if (event['minerReward'] != null) {
          otherTransfers.add(MinerRewardEvent.fromJson(event['minerReward']));
        }
      }

      return OtherTransfersResult(transfers: otherTransfers, totalCount: totalCount);
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
  }) async {
    try {
      final results = await Future.wait([
        fetchScheduledReversibleTransfers(accountIds: accountIds, limit: limit, offset: scheduledOffset),
        fetchOtherTransfers(accountIds: accountIds, limit: limit, offset: otherOffset),
      ]);

      final scheduledReversibleTransfers = results[0] as List<ReversibleTransferEvent>;
      final otherTransfers = results[1] as OtherTransfersResult;

      final nextOtherOffset = otherOffset + limit;
      final nextScheduledOffset = scheduledOffset + limit;

      return SortedTransactionsList(
        scheduledReversibleTransfers: scheduledReversibleTransfers,
        otherTransfers: otherTransfers.transfers,
        nextOtherOffset: nextOtherOffset,
        nextScheduledOffset: nextScheduledOffset,
        hasMore: nextOtherOffset < otherTransfers.totalCount,
      );
    } catch (e, stackTrace) {
      print('Error fetching all transaction types: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Searches for transactions matching the criteria of a pending transaction.
  /// This is used to find if a broadcast transaction has been confirmed.
  /// Searches both transfer and reversibleTransfer types.
  Future<TransactionEvent?> searchForPendingTransaction({
    required String from,
    required String to,
    required BigInt amount,
    required bool isReversible,
    required int blockHeightAfter,
    int limit = 10,
  }) async {
    print(
      'Searching for pending transaction: $from → $to, amount: $amount, '
      'reversible: $isReversible, after block: $blockHeightAfter',
    );

    final Map<String, dynamic> requestBody = {
      'query': isReversible ? _searchPendingReversibleQuery : _searchPendingTransferQuery,
      'variables': {
        'from': from,
        'to': to,
        'amount': amount.toString(),
        'blockHeightAfter': blockHeightAfter,
        'limit': limit,
      },
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

      final List<dynamic>? events = data['events'];

      if (events == null || events.isEmpty) {
        print('No matching transactions found for pending transaction');
        return null;
      }

      final TransactionEvent transaction;
      var eventJson = events.first!;

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
      final block = transaction.blockNumber;

      print('Found 1 matching transactions for pending transaction at block $block');
      return transaction;
    } catch (e, stackTrace) {
      print('Error searching for pending transaction: $e');
      print(stackTrace);
      rethrow;
    }
  }
}
