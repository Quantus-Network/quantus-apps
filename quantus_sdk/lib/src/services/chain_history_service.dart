import '../constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Required for jsonEncode and jsonDecode

import '../models/event_type.dart';
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

  // GraphQL query to fetch transfers for a specific account
  final String _eventsQuery = r'''
query MyQuery($accountId: String!, $limit: Int!, $offset: Int!) {
  events(
    where: {
      OR: [
        { transfer: { from: { id_eq: $accountId } } },
        { transfer: { to: { id_eq: $accountId } } },
        { reversibleTransfer: { from: { id_eq: $accountId } } },
        { reversibleTransfer: { to: { id_eq: $accountId } } }
      ]
    },
    orderBy: timestamp_DESC,
    limit: $limit,
    offset: $offset
  ) {
    id
    type
    timestamp
    extrinsicHash
    transfer {
      id
      from { id }
      to { id }
      amount
      fee
      timestamp
      extrinsicHash
      block {
        height
      }
    }
    reversibleTransfer {
      id
      from { id }
      to { id }
      amount
      txId
      status
      scheduledAt
      timestamp
      extrinsicHash
      block {
        height
      }
    }
  }
}
  ''';

  // Method to fetch transfers using http
  Future<TransferResult> fetchTransfers({required String accountId, int limit = 10, int offset = 0}) async {
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    print('fetchTransfers for account: $accountId from $uri (limit: $limit, offset: $offset)');

    // Construct the GraphQL request body
    final Map<String, dynamic> requestBody = {
      'query': _eventsQuery,
      'variables': <String, dynamic>{'accountId': accountId, 'limit': limit, 'offset': offset},
    };

    print('fetchTransfers requestBody: $requestBody');

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
        final String typeStr = (event['type'] as String).toUpperCase();
        final eventType = EventType.values.firstWhere((e) => e.toString().split('.').last == typeStr);

        if (eventType == EventType.TRANSFER && event['transfer'] != null) {
          final transferData = event['transfer'] as Map<String, dynamic>;
          transferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(TransferEvent.fromJson(transferData));
        } else if (eventType == EventType.REVERSIBLE_TRANSFER && event['reversibleTransfer'] != null) {
          final reversibleTransferData = event['reversibleTransfer'] as Map<String, dynamic>;
          reversibleTransferData['extrinsicHash'] ??= event['extrinsicHash'];
          transactions.add(ReversibleTransferEvent.fromJson(reversibleTransferData));
        }
      }

      final bool hasMore = events.length == limit;
      final int nextOffset = offset + events.length;

      return TransferResult(combinedTransfers: transactions, hasMore: hasMore, nextOffset: nextOffset);
    } catch (e) {
      print('Error fetching transfers via http: $e');
      rethrow;
    }
  }

  // Add other methods for fetching historical data as needed
}
