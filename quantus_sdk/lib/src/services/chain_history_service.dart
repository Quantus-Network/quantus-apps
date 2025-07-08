import '../constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Required for jsonEncode and jsonDecode

import '../models/transaction_event.dart';

class TransferList {
  final List<TransactionEvent> transfers;
  final bool hasMore;
  final int nextOffset;

  TransferList({required this.transfers, required this.hasMore, required this.nextOffset});
}

class TransferResult {
  final List<TransactionEvent> combinedTransfers;
  final bool hasMore;
  final int nextOffset;

  TransferResult({required this.combinedTransfers, required this.hasMore, required this.nextOffset});
}

class ChainHistoryService {
  final String _graphQlEndpoint = AppConstants.graphQlEndpoint;

  // We don't need a client instance anymore, just the endpoint
  ChainHistoryService();

  final String _scheduledTransfersQuery = r'''
query ScheduledTransfersByAccount($account: String!) {
  events(
    where: {
      reversibleTransfer: {
        AND:[
          { status_eq: SCHEDULED },
          {
            OR: [
              { from: { id_eq: $account } },
              { to: { id_eq: $account } }
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
      }
      extrinsicHash
      timestamp
    }
  }
}
''';

  // GraphQL query to fetch transfers for a specific account
  final String _eventsQuery = r'''
query EventsByAccount($account: String!, $limit: Int!, $offset: Int!) {
  events(
    limit: $limit
    offset: $offset
    where: {
      AND: [
        { extrinsicHash_isNull: false }      # <- keep only events that HAVE a hash
        { OR: [
            { transfer: {
                OR: [
                  { from: { id_eq: $account } }
                  { to:   { id_eq: $account } }
                ]}
            }
            { reversibleTransfer: {
                OR: [
                  { from: { id_eq: $account } }
                  { to:   { id_eq: $account } }
                ]}
            }
        ]}
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
      }
      extrinsicHash
      timestamp
    }
    extrinsicHash
  }
}
  ''';

  Future<List<ReversibleTransferEvent>> fetchScheduledTransfers({required String accountId}) async {
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    final Map<String, dynamic> requestBody = {
      'query': _scheduledTransfersQuery,
      'variables': {'account': accountId},
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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

      for (var transfer in result) {
        print('Transfer: ${transfer.scheduledAt} ${transfer.status}');
      }
      return result;
    } catch (e, stackTrace) {
      print('Error fetching scheduled transfers: $e');
      print(stackTrace);
      rethrow;
    }
  }

  // Method to fetch transfers using http
  Future<TransferResult> fetchAllTransfers({required String accountId, int limit = 10, int offset = 0}) async {
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    print('fetchTransfers for account: $accountId from $uri (limit: $limit, offset: $offset)');

    // Construct the GraphQL request body
    final Map<String, dynamic> requestBody = {
      'query': _eventsQuery,
      'variables': <String, dynamic>{'account': accountId, 'limit': limit, 'offset': offset},
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
        return TransferResult(combinedTransfers: [], hasMore: false, nextOffset: offset);
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
        }
      }

      final bool hasMore = events.length == limit;
      final int nextOffset = offset + events.length;

      return TransferResult(combinedTransfers: transactions, hasMore: hasMore, nextOffset: nextOffset);
    } catch (e, stackTrace) {
      print('Error fetching transfers via http: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Add other methods for fetching historical data as needed
}
