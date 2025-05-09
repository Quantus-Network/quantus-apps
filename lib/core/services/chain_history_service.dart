import 'package:resonance_network_wallet/core/constants/app_constants.dart';
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

class ChainHistoryService {
  final String _graphQlEndpoint = AppConstants.graphQlEndpoint;

  // We don't need a client instance anymore, just the endpoint
  ChainHistoryService();

  // GraphQL query to fetch transfers for a specific account
  final String _transfersQuery = r'''
query MyQuery($accountId: String!) {
  accounts(where: {id_eq: $accountId}) {
    id
    transfersTo(orderBy: timestamp_DESC) {
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
    transfersFrom(orderBy: timestamp_DESC) {
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
  Future<List<Transfer>> fetchTransfers({required String accountId}) async {
    final Uri uri = Uri.parse('$_graphQlEndpoint/graphql');
    print('fetchTransfers for account: $accountId from $uri');

    // Construct the GraphQL request body
    final Map<String, dynamic> requestBody = {
      'query': _transfersQuery,
      'variables': <String, dynamic>{
        'accountId': accountId,
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

      // Print raw response for debugging
      // print('Raw GraphQL response status: ${response.statusCode}');
      // print('Raw GraphQL response body: ${response.body}');

      if (response.statusCode != 200) {
        // Handle non-200 status codes
        throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      // Parse the JSON response
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      // Check for GraphQL errors in the response body
      if (responseBody['errors'] != null) {
        print('GraphQL errors in response: ${responseBody['errors']}');
        throw Exception('GraphQL errors: ${responseBody['errors'].toString()}');
      }

      // Extract and parse the data
      final Map<String, dynamic>? data = responseBody['data'];
      if (data == null) {
        throw Exception('GraphQL response data is null.');
      }

      final List<dynamic>? accounts = data['accounts'];

      if (accounts == null || accounts.isEmpty) {
        return []; // Return empty list if no accounts found
      }

      // Assuming the query returns exactly one account for the given ID
      final Map<String, dynamic> accountData = accounts.first;

      final List<dynamic>? transfersTo = accountData['transfersTo'];
      final List<dynamic>? transfersFrom = accountData['transfersFrom'];

      final List<dynamic> allTransfersData = [];
      if (transfersTo != null) {
        allTransfersData.addAll(transfersTo);
      }
      if (transfersFrom != null) {
        allTransfersData.addAll(transfersFrom);
      }

      // Map the raw transfer data to Transfer objects
      final List<Transfer> transfers = allTransfersData.map((transferJson) {
        return Transfer.fromJson(transferJson as Map<String, dynamic>);
      }).toList();

      // You might want to sort transfers by timestamp here if needed
      // transfers.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return transfers;
    } catch (e) {
      // Handle any exceptions during the HTTP request or JSON parsing
      print('Error fetching transfers via http: $e');
      throw e; // Re-throw the caught exception
    }
  }

  // Add other methods for fetching historical data as needed
}
