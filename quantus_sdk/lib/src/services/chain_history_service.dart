import 'dart:convert'; // Required for jsonEncode and jsonDecode

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/models/sorted_transactions.dart';

import '../constants/app_constants.dart';
import '../models/transaction_event.dart';

class TransferList {
  final List<TransactionEvent> transfers;
  final bool hasMore;
  final int nextOffset;

  TransferList({
    required this.transfers,
    required this.hasMore,
    required this.nextOffset,
  });
}

class TransferResult {
  final List<TransactionEvent> combinedTransfers;
  final bool hasMore;
  final int nextOffset;

  TransferResult({
    required this.combinedTransfers,
    required this.hasMore,
    required this.nextOffset,
  });
}

class BlockQueryResponse {
  final bool blockExists;
  final List<TransactionEvent> transactions;

  BlockQueryResponse({required this.blockExists, required this.transactions});
}

class ChainHistoryService {
  final String _graphQlEndpoint = AppConstants.graphQlEndpoint;

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

  // GraphQL query to fetch transfers for a specific account
  final String _eventsByAccountsQuery = r'''
query EventsByAccounts($accounts: [String!]!, $limit: Int!, $offset: Int!) {
  events(
    limit: $limit
    offset: $offset
    where: {
      AND: [
        { extrinsicHash_isNull: false } 
        { OR: [
            { transfer: {
                OR: [
                  { from: { id_in: $accounts } }
                  { to:   { id_in: $accounts } }
                ]}
            }
            { reversibleTransfer: {
              AND: [
                { status_not_eq: SCHEDULED },
                {
                  OR: [
                    { from: { id_in: $accounts } },
                    { to: { id_in: $accounts } }
                  ]
                }
              ]
              }
            }
          ]
        }
      ]
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
}
''';

  final String _reversibleTransactionsInBlockQuery = r'''
query TransactionsAndBlockInBlock(
  $blockHash: String!,
  $from: String!,
  $to: String!
) {
  blocks(where: { hash_eq: $blockHash }, limit: 1) {
    id
  }
  events(
    limit: 500
    offset: 0
    where: {
      block: { hash_eq: $blockHash },
      reversibleTransfer: {
        from: { id_eq: $from },
        to: { id_eq: $to }
      }
    }
    orderBy: timestamp_DESC
  ) {
    id
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
    extrinsicHash
  }
}
''';

  final String _transferInBlockQuery = r'''
query TransactionsAndBlockInBlock(
  $blockHash: String!,
  $from: String!,
  $to: String!
) {
  blocks(where: { hash_eq: $blockHash }, limit: 1) {
    id
  }
  events(
    limit: 500
    offset: 0
    where: {
      block: { hash_eq: $blockHash },
      transfer: {
        from: { id_eq: $from },
        to: { id_eq: $to }
      }
    }
    orderBy: timestamp_DESC
  ) {
    id
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
    extrinsicHash
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

  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    int offset = 0,
    String? printName,
  }) async {
    final scheduled = await fetchScheduledTransfers(accountIds: accountIds);
    final other = await _fetchOtherTransfers(
      accountIds: accountIds,
      limit: limit,
      offset: offset,
      printName: printName,
    );

    return SortedTransactionsList(
      reversibleTransfers: scheduled,
      otherTransfers: other.transfers,
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

    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');

    // print(
    //   'Fetching transactions by hash: $transactionHashes (limit: $limit, offset: $offset)',
    // );

    final Map<String, dynamic> requestBody = {
      'query': _transactionsByHashQuery,
      'variables': {
        'transactionHashes': transactionHashes,
        'limit': limit,
        'offset': offset,
      },
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}',
        );
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
          final reversibleTransferData =
              event['reversibleTransfer'] as Map<String, dynamic>;
          reversibleTransferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(
            ReversibleTransferEvent.fromJson(reversibleTransferData),
          );
        }
      }

      // print(
      //   'Found ${transactions.length} transactions for ${transactionHashes.length} hashes',
      // );
      for (final t in transactions) {
        print(
          '${t.id} ${t.extrinsicHash} ${(t as ReversibleTransferEvent).status}',
        );
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
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    final Map<String, dynamic> requestBody = {
      'query': _scheduledTransfersQuery,
      'variables': {'accounts': accountIds, 'limit': limit, 'offset': offset},
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}',
        );
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['errors'] != null) {
        throw Exception('GraphQL errors: ${responseBody['errors']}');
      }

      final List<dynamic>? events = responseBody['data']?['events'];
      if (events == null) {
        return [];
      }

      final result = events
          .map(
            (event) =>
                ReversibleTransferEvent.fromJson(event['reversibleTransfer']),
          )
          .toList();

      return result;
    } catch (e, stackTrace) {
      print('Error fetching scheduled transfers: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<TransferList> _fetchOtherTransfers({
    required List<String> accountIds,
    int limit = 10,
    int offset = 0,
    String? printName,
  }) async {
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    print(
      '${printName ?? ''} '
      ' fetchTransfers for account: $accountIds from $uri (limit: $limit, offset: $offset)',
    );

    // Construct the GraphQL request body
    final Map<String, dynamic> requestBody = {
      'query': _eventsByAccountsQuery,
      'variables': <String, dynamic>{
        'accounts': accountIds,
        'limit': limit,
        'offset': offset,
      },
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}',
        );
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
        return TransferList(transfers: [], hasMore: false, nextOffset: offset);
      }

      final List<TransactionEvent> transactions = [];
      for (var eventJson in events) {
        final event = eventJson as Map<String, dynamic>;

        if (event['transfer'] != null) {
          final transferData = event['transfer'] as Map<String, dynamic>;
          transferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(TransferEvent.fromJson(transferData));
        } else if (event['reversibleTransfer'] != null) {
          final reversibleTransferData =
              event['reversibleTransfer'] as Map<String, dynamic>;
          reversibleTransferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(
            ReversibleTransferEvent.fromJson(reversibleTransferData),
          );
        }
      }

      final bool hasMore = events.length == limit;
      final int nextOffset = offset + events.length;

      return TransferList(
        transfers: transactions,
        hasMore: hasMore,
        nextOffset: nextOffset,
      );
    } catch (e, stackTrace) {
      print('Error fetching transfers: $e');
      print(stackTrace);
      rethrow;
    }
  }

  // Add other methods for fetching historical data as needed

  Future<BlockQueryResponse> getTransactionsInBlock({
    required String blockHash,
    required String from,
    required String to,
    required bool isReversible,
  }) async {
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');

    print('Fetching transactions in block: $blockHash');

    final Map<String, dynamic> requestBody = {
      'query': isReversible
          ? _reversibleTransactionsInBlockQuery
          : _transferInBlockQuery,
      'variables': {'blockHash': blockHash, 'from': from, 'to': to},
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}',
        );
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

      final List<dynamic>? blocks = data['blocks'];
      final bool blockExists = blocks != null && blocks.isNotEmpty;

      final List<dynamic>? events = data['events'];

      if (events == null || events.isEmpty) {
        return BlockQueryResponse(blockExists: blockExists, transactions: []);
      }

      final List<TransactionEvent> transactions = [];
      for (var eventJson in events) {
        final event = eventJson as Map<String, dynamic>;

        if (event['transfer'] != null) {
          final transferData = event['transfer'] as Map<String, dynamic>;
          transferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(TransferEvent.fromJson(transferData));
        } else if (event['reversibleTransfer'] != null) {
          final reversibleTransferData =
              event['reversibleTransfer'] as Map<String, dynamic>;
          reversibleTransferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(
            ReversibleTransferEvent.fromJson(reversibleTransferData),
          );
        }
      }

      print('Found ${transactions.length} transactions in block $blockHash');
      return BlockQueryResponse(
        blockExists: blockExists,
        transactions: transactions,
      );
    } catch (e, stackTrace) {
      print('Error fetching transactions by block hash: $e');
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
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');

    print(
      'Searching for pending transaction: $from → $to, amount: $amount, '
      'reversible: $isReversible, after block: $blockHeightAfter',
    );

    final Map<String, dynamic> requestBody = {
      'query': isReversible
          ? _searchPendingReversibleQuery
          : _searchPendingTransferQuery,
      'variables': {
        'from': from,
        'to': to,
        'amount': amount.toInt(),
        'blockHeightAfter': blockHeightAfter,
        'limit': limit,
      },
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}',
        );
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
      print('result $data');
      print('events $events');

      if (events == null || events.isEmpty) {
        print('No matching transactions found for pending transaction');
        return null;
      }

      final TransactionEvent transaction;
      var eventJson = events.first!;

      if (isReversible) {
        final reversibleTransferData =
            eventJson['reversibleTransfer'] as Map<String, dynamic>;
        transaction = ReversibleTransferEvent.fromJson(reversibleTransferData);
      } else {
        final transferData = eventJson['transfer'] as Map<String, dynamic>;
        transaction = TransferEvent.fromJson(transferData);
      }

      print('Found 1 matching transactions for pending transaction');
      return transaction;
    } catch (e, stackTrace) {
      print('Error searching for pending transaction: $e');
      print(stackTrace);
      rethrow;
    }
  }
}
