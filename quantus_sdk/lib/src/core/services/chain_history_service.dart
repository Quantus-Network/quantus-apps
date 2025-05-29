import '../constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Required for jsonEncode and jsonDecode

// Data class to represent a single transfer
class Transfer {
  final String id;
  final String from;
  final String to;
  final String amount;
  final String timestamp;
  final String? fee;
  final String? extrinsicHash;
  final int? blockNumber;

  Transfer({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.timestamp,
    this.fee,
    this.extrinsicHash,
    this.blockNumber,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) {
    return Transfer(
      id: json['id'] as String,
      from: json['from']?['id'] as String? ?? '', // Handle potential null or missing nested id
      to: json['to']?['id'] as String? ?? '', // Handle potential null or missing nested id
      amount: json['amount'] as String,
      timestamp: json['timestamp'] as String,
      fee: json['fee'] as String?,
      extrinsicHash: json['extrinsicHash'] as String?,
      blockNumber: json['blockNumber'] as int?,
    );
  }

  @override
  String toString() {
    return 'Transfer{id: $id, from: $from, to: $to, amount: $amount, timestamp: $timestamp, fee: $fee, extrinsicHash: $extrinsicHash, blockNumber: $blockNumber}';
  }
}

class TransferList {
  final List<Transfer> transfers;
  final bool hasMore;
  final int nextOffset;

  TransferList({
    required this.transfers,
    required this.hasMore,
    required this.nextOffset,
  });
}

class TransferResult {
  final List<Transfer> combinedTransfers;
  final bool hasMoreTo;
  final bool hasMoreFrom;
  final int nextToOffset;
  final int nextFromOffset;

  TransferResult({
    required this.combinedTransfers,
    required this.hasMoreTo,
    required this.hasMoreFrom,
    required this.nextToOffset,
    required this.nextFromOffset,
  });
}

class ChainHistoryService {
  final String _graphQlEndpoint = AppConstants.graphQlEndpoint;

  // We don't need a client instance anymore, just the endpoint
  ChainHistoryService();

  // GraphQL query to fetch transfers for a specific account
  final String _transfersQuery = r'''
query MyQuery($accountId: String!, $limit: Int!, $toOffset: Int!, $fromOffset: Int!) {
  accounts(where: {id_eq: $accountId}) {
    id
    transfersTo(orderBy: timestamp_DESC, limit: $limit, offset: $toOffset) {
      id
      from {
        id
      }
      to {
        id
      }
      amount
      timestamp
      fee
      extrinsicHash
      blockNumber
    }
    transfersFrom(orderBy: timestamp_DESC, limit: $limit, offset: $fromOffset) {
      id
      from {
        id
      }
      to {
        id
      }
      amount
      timestamp
      fee
      extrinsicHash
      blockNumber
    }
  }
}
  ''';

  // Method to fetch transfers using http
  Future<TransferResult> fetchTransfers({
    required String accountId,
    int limit = 10,
    int toOffset = 0,
    int fromOffset = 0,
  }) async {
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    print(
        'fetchTransfers for account: $accountId from $uri (limit: $limit, toOffset: $toOffset, fromOffset: $fromOffset)');

    // Construct the GraphQL request body
    final Map<String, dynamic> requestBody = {
      'query': _transfersQuery,
      'variables': <String, dynamic>{
        'accountId': accountId,
        'limit': limit,
        'toOffset': toOffset,
        'fromOffset': fromOffset,
      },
    };

    try {
      final http.Response response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
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

      final List<dynamic>? accounts = data['accounts'];

      if (accounts == null || accounts.isEmpty) {
        return TransferResult(
          combinedTransfers: [],
          hasMoreTo: false,
          hasMoreFrom: false,
          nextToOffset: toOffset,
          nextFromOffset: fromOffset,
        );
      }

      final Map<String, dynamic> accountData = accounts.first;

      final List<dynamic>? transfersTo = accountData['transfersTo'];
      final List<dynamic>? transfersFrom = accountData['transfersFrom'];

      // Process transfersTo
      final List<Transfer> toTransfers = (transfersTo ?? []).map((transferJson) {
        return Transfer.fromJson(transferJson as Map<String, dynamic>);
      }).toList();

      // Process transfersFrom
      final List<Transfer> fromTransfers = (transfersFrom ?? []).map((transferJson) {
        return Transfer.fromJson(transferJson as Map<String, dynamic>);
      }).toList();

      // Combine all transfers
      final List<Transfer> newTransfers = [...toTransfers, ...fromTransfers];

      // Sort by timestamp in descending order
      newTransfers.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Take only the requested number of transfers
      final combinedTransfers = newTransfers.take(limit).toList();

      // Count the number of transfers included in the limited list.
      int numberOfToTransfers = 0;
      int numberOfFromTransfers = 0;
      for (Transfer t in combinedTransfers) {
        if (t.from == accountId) {
          numberOfFromTransfers++;
        } else {
          numberOfToTransfers++;
        }
      }
      // print('numberOfToTransfers: $numberOfToTransfers');
      // print('numberOfFromTransfers: $numberOfFromTransfers');
      // print('all loaded to: $numberOfToTransfers');
      // print('numberOfFromTransfers: $numberOfFromTransfers');
      // print('limit: ${limit}');

      // Note This is a little tricky because we have 2 lists that get combined into one with the same limit
      // So we need to keep track of has more and offsets for each list, and combine them with the wild
      // logic below - AI trap, AI can't figure this out.
      return TransferResult(
        combinedTransfers: combinedTransfers,
        hasMoreTo: toTransfers.length == limit || numberOfToTransfers < toTransfers.length,
        hasMoreFrom: fromTransfers.length == limit || numberOfFromTransfers < fromTransfers.length,
        nextToOffset: toOffset + numberOfToTransfers,
        nextFromOffset: fromOffset + numberOfFromTransfers,
      );
    } catch (e) {
      print('Error fetching transfers via http: $e');
      rethrow;
    }
  }

  // Add other methods for fetching historical data as needed
}
