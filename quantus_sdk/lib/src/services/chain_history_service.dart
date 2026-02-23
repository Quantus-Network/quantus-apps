import 'dart:convert'; // Required for jsonEncode and jsonDecode

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';

class TransferList {
  final List<TransactionEvent> transfers;
  final bool hasMore;
  final int nextTransfersOffset;
  final int nextReversibleOffset;
  final int nextRewardsOffset;

  TransferList({
    required this.transfers,
    required this.hasMore,
    required this.nextTransfersOffset,
    required this.nextReversibleOffset,
    required this.nextRewardsOffset,
  });
}

class BlockQueryResponse {
  final bool blockExists;
  final List<TransactionEvent> transactions;

  BlockQueryResponse({required this.blockExists, required this.transactions});
}

class ChainHistoryService {
  final GraphQlEndpointService _graphQlEndpointService = GraphQlEndpointService();

  // We don't need a client instance anymore, just the endpoint
  ChainHistoryService();

  final String _scheduledTransfersQuery = r'''
query ScheduledTransfersByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) {
  events(
    limit: $limit
    offset: $offset
    where: {
      reversibleTransfer: {
        AND: [
          { status_eq: SCHEDULED },
          {
            OR: [
              { from: { id_in: $accounts } },
              { to: { id_in: $accounts } }
            ]
          }
        ]
      }
    }
    orderBy: reversibleTransfer_scheduledAt_DESC
  ) {
    id
    reversibleTransfer {
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
      status
      block {
        height
        hash
      }
      extrinsicHash
      timestamp
    }
  }
}''';

  // GraphQL query to fetch transactions by their hash
  final String _transactionsByHashQuery = r'''
query TransactionsByHash($transactionHashes: [String!]!, $limit: Int!, $offset: Int!) {
  events(
    limit: $limit
    offset: $offset
    where: {
      extrinsicHash_in: $transactionHashes
    }
    orderBy: timestamp_DESC
  ) {
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
    }
    reversibleTransfer {
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
      status
      block {
        height
        hash
      }
      extrinsicHash
      timestamp
    }
    extrinsicHash
  }
}''';

  final String _transfersByAccountsQuery = r'''
query TransfersByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) {
  events(
    limit: $limit, offset: $offset,
    where: { extrinsicHash_isNull: false, transfer: { OR: [{ from: { id_in: $accounts } }, { to: { id_in: $accounts } }] } },
    orderBy: timestamp_DESC
  ) {
    id
    transfer { id amount timestamp from { id } to { id } block { height hash } extrinsicHash timestamp fee }
    extrinsicHash
  }
}''';

  final String _reversibleByAccountsQuery = r'''
query ReversibleByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) {
  events(
    limit: $limit, offset: $offset,
    where: { extrinsicHash_isNull: false, reversibleTransfer: { AND: [{ status_not_eq: SCHEDULED }, { OR: [{ from: { id_in: $accounts } }, { to: { id_in: $accounts } }] }] } },
    orderBy: timestamp_DESC
  ) {
    id
    reversibleTransfer { id amount timestamp from { id } to { id } txId scheduledAt status block { height hash } extrinsicHash timestamp }
    extrinsicHash
  }
}''';

  final String _rewardsByAccountsQuery = r'''
query RewardsByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) {
  events(
    limit: $limit, offset: $offset,
    where: { minerReward: { miner: { id_in: $accounts } } },
    orderBy: timestamp_DESC
  ) {
    id
    minerReward { id reward timestamp miner { id } block { height hash } }
    extrinsicHash
  }
}''';

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
    reversibleTransfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      txId
      scheduledAt
      status
      block { height hash }
      extrinsicHash
      timestamp
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
      reversibleTransfer: {
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
    reversibleTransfer {
      id
      amount
      timestamp
      from { id }
      to { id }
      txId
      scheduledAt
      status
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

  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    int transfersOffset = 0,
    int reversibleOffset = 0,
    int rewardsOffset = 0,
    int scheduledOffset = 0,
  }) async {
    final results = await Future.wait([
      fetchScheduledTransfers(accountIds: accountIds, limit: limit, offset: scheduledOffset),
      _fetchOtherTransfers(
        accountIds: accountIds,
        limit: limit,
        transfersOffset: transfersOffset,
        reversibleOffset: reversibleOffset,
        rewardsOffset: rewardsOffset,
      ),
    ]);

    final scheduled = results[0] as List<ReversibleTransferEvent>;
    final other = results[1] as TransferList;
    return SortedTransactionsList(
      reversibleTransfers: scheduled,
      otherTransfers: other.transfers,
      nextTransfersOffset: other.nextTransfersOffset,
      nextReversibleOffset: other.nextReversibleOffset,
      nextRewardsOffset: other.nextRewardsOffset,
      nextScheduledOffset: scheduledOffset + scheduled.length,
      hasMore: other.hasMore,
    );
  }

  // Make a graphQL query for specific transaction hashes, get the results back
  // Mostly to check if reversibles have been executed or failed.
  Future<List<TransactionEvent>> fetchTransactionsByTransactionHash({
    required List<String> transactionHashes,
    int limit = 20,
    int offset = 0,
  }) async {
    if (transactionHashes.isEmpty) {
      return [];
    }

    final Map<String, dynamic> requestBody = {
      'query': _transactionsByHashQuery,
      'variables': {'transactionHashes': transactionHashes, 'limit': limit, 'offset': offset},
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
        print('No transactions found for hashes: $transactionHashes');
        return [];
      }

      final List<TransactionEvent> transactions = [];
      for (var eventJson in events) {
        final event = eventJson as Map<String, dynamic>;

        if (event['transfer'] != null) {
          final transferData = event['transfer'] as Map<String, dynamic>;
          transferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(TransferEvent.fromJson(transferData));
        } else if (event['reversibleTransfer'] != null) {
          final reversibleTransferData = event['reversibleTransfer'] as Map<String, dynamic>;
          reversibleTransferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(ReversibleTransferEvent.fromJson(reversibleTransferData));
        } else if (event['minerReward'] != null) {
          final minerRewardData = event['minerReward'] as Map<String, dynamic>;
          minerRewardData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(MinerRewardEvent.fromJson(minerRewardData));
        }
      }

      for (final t in transactions) {
        print('${t.id} ${t.extrinsicHash} ${(t as ReversibleTransferEvent).status}');
      }
      return transactions;
    } catch (e, stackTrace) {
      print('Error fetching transactions by hash: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<List<ReversibleTransferEvent>> fetchScheduledTransfers({
    required List<String> accountIds,
    int limit = 10,
    int offset = 0,
  }) async {
    final Map<String, dynamic> requestBody = {
      'query': _scheduledTransfersQuery,
      'variables': {'accounts': accountIds, 'limit': limit, 'offset': offset},
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

      final List<dynamic>? events = responseBody['data']?['events'];
      if (events == null) {
        return [];
      }

      final result = events.map((event) => ReversibleTransferEvent.fromJson(event['reversibleTransfer'])).toList();

      return result;
    } catch (e, stackTrace) {
      sw.stop();
      printTiming('fetchScheduledTransfers FAILED', sw.elapsedMilliseconds);
      print('Error fetching scheduled transfers: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<List<TransactionEvent>> _fetchSingleType({
    required String query,
    required String label,
    required List<String> accountIds,
    required int limit,
    required int offset,
    required TransactionEvent? Function(Map<String, dynamic> event) parser,
  }) async {
    final body = jsonEncode({
      'query': query,
      'variables': <String, dynamic>{'accounts': accountIds, 'limit': limit, 'offset': offset},
    });

    final sw = Stopwatch()..start();
    final http.Response response = await _graphQlEndpointService.post(body: body);
    printTiming('$label HTTP', sw.elapsedMilliseconds);

    if (response.statusCode != 200) {
      throw Exception('GraphQL $label failed: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL $label errors: ${responseBody['errors']}');
    }

    final events = responseBody['data']?['events'] as List<dynamic>?;
    if (events == null || events.isEmpty) return [];

    return events.map((e) => parser(e as Map<String, dynamic>)).whereType<TransactionEvent>().toList();
  }

  Future<TransferList> _fetchOtherTransfers({
    required List<String> accountIds,
    int limit = 10,
    int transfersOffset = 0,
    int reversibleOffset = 0,
    int rewardsOffset = 0,
  }) async {
    try {
      final results = await Future.wait([
        _fetchSingleType(
          query: _transfersByAccountsQuery,
          label: 'transfers',
          accountIds: accountIds,
          limit: limit,
          offset: transfersOffset,
          parser: (event) {
            if (event['transfer'] == null) return null;
            final d = event['transfer'] as Map<String, dynamic>;
            d['extrinsicHash'] ??= event['extrinsicHash'];
            return TransferEvent.fromJson(d);
          },
        ),
        _fetchSingleType(
          query: _reversibleByAccountsQuery,
          label: 'reversible',
          accountIds: accountIds,
          limit: limit,
          offset: reversibleOffset,
          parser: (event) {
            if (event['reversibleTransfer'] == null) return null;
            final d = event['reversibleTransfer'] as Map<String, dynamic>;
            d['extrinsicHash'] ??= event['extrinsicHash'];
            return ReversibleTransferEvent.fromJson(d);
          },
        ),
        _fetchSingleType(
          query: _rewardsByAccountsQuery,
          label: 'rewards',
          accountIds: accountIds,
          limit: limit,
          offset: rewardsOffset,
          parser: (event) {
            if (event['minerReward'] == null) return null;
            final d = event['minerReward'] as Map<String, dynamic>;
            d['extrinsicHash'] ??= event['extrinsicHash'];
            return MinerRewardEvent.fromJson(d);
          },
        ),
      ]);

      final all = [...results[0], ...results[1], ...results[2]];
      all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final trimmed = all.take(limit).toList();

      final usedTransfers = trimmed.whereType<TransferEvent>().length;
      final usedReversible = trimmed.whereType<ReversibleTransferEvent>().length;
      final usedRewards = trimmed.whereType<MinerRewardEvent>().length;

      final anyHasMore = results[0].length == limit || results[1].length == limit || results[2].length == limit;

      return TransferList(
        transfers: trimmed,
        hasMore: anyHasMore,
        nextTransfersOffset: transfersOffset + usedTransfers,
        nextReversibleOffset: reversibleOffset + usedReversible,
        nextRewardsOffset: rewardsOffset + usedRewards,
      );
    } catch (e, stackTrace) {
      print('Error fetching transfers: $e');
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
        final reversibleTransferData = eventJson['reversibleTransfer'] as Map<String, dynamic>;
        transaction = ReversibleTransferEvent.fromJson(reversibleTransferData);
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
