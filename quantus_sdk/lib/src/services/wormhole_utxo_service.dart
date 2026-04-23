import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';

/// A wormhole transfer that may be spent later with a ZK proof.
class WormholeTransfer {
  final String id;
  final String wormholeAddress;
  final String fromAddress;
  final BigInt amount;
  final BigInt transferCount;
  final BigInt leafIndex;
  final int blockNumber;
  final String blockHash;
  final DateTime timestamp;

  const WormholeTransfer({
    required this.id,
    required this.wormholeAddress,
    required this.fromAddress,
    required this.amount,
    required this.transferCount,
    required this.leafIndex,
    required this.blockNumber,
    required this.blockHash,
    required this.timestamp,
  });

  factory WormholeTransfer.fromJson(Map<String, dynamic> json) {
    final block = json['block'] as Map<String, dynamic>?;
    return WormholeTransfer(
      id: json['id'] as String,
      wormholeAddress: json['to']?['id'] as String? ?? '',
      fromAddress: json['from']?['id'] as String? ?? '',
      amount: BigInt.parse(json['amount'] as String),
      transferCount: BigInt.parse(json['transferCount'] as String),
      leafIndex: BigInt.parse(json['leafIndex'] as String),
      blockNumber: block?['height'] as int? ?? 0,
      blockHash: block?['hash'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() =>
      'WormholeTransfer{id: $id, to: $wormholeAddress, from: $fromAddress, '
      'amount: $amount, transferCount: $transferCount, leafIndex: $leafIndex, block: $blockNumber}';
}

/// Service for querying wormhole transfers and consumed nullifiers from Subsquid.
class WormholeUtxoService {
  final GraphQlEndpointService _graphQlEndpoint = GraphQlEndpointService();

  static const String _transfersToWormholeQuery = r'''
query WormholeTransfers($wormholeAddress: String!, $limit: Int!, $offset: Int!) {
  transfers(
    limit: $limit
    offset: $offset
    where: {
      to: { id_eq: $wormholeAddress }
    }
    orderBy: timestamp_DESC
  ) {
    id
    from { id }
    to { id }
    amount
    leafIndex
    transferCount
    timestamp
    block {
      height
      hash
    }
  }
}''';

  static const String _transfersToMultipleQuery = r'''
query WormholeTransfersMultiple($wormholeAddresses: [String!]!, $limit: Int!, $offset: Int!) {
  transfers(
    limit: $limit
    offset: $offset
    where: {
      to: { id_in: $wormholeAddresses }
    }
    orderBy: timestamp_DESC
  ) {
    id
    from { id }
    to { id }
    amount
    leafIndex
    transferCount
    timestamp
    block {
      height
      hash
    }
  }
}''';

  static const String _nullifiersQuery = r'''
query CheckNullifiers($nullifiers: [String!]!) {
  wormholeNullifiers(
    where: { nullifier_in: $nullifiers }
  ) {
    nullifier
  }
}''';

  /// Fetch all wormhole transfers to [wormholeAddress].
  Future<List<WormholeTransfer>> getTransfersTo(String wormholeAddress, {int limit = 100, int offset = 0}) async {
    final body = jsonEncode({
      'query': _transfersToWormholeQuery,
      'variables': {'wormholeAddress': wormholeAddress, 'limit': limit, 'offset': offset},
    });

    final response = await _graphQlEndpoint.post(body: body);
    if (response.statusCode != 200) {
      throw Exception('GraphQL wormhole transfers query failed: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final transfers = responseBody['data']?['transfers'] as List<dynamic>?;
    if (transfers == null || transfers.isEmpty) return [];
    return transfers.map((t) => WormholeTransfer.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Fetch transfers to multiple wormhole addresses in one query.
  Future<List<WormholeTransfer>> getTransfersToMultiple(
    List<String> wormholeAddresses, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (wormholeAddresses.isEmpty) return [];

    final body = jsonEncode({
      'query': _transfersToMultipleQuery,
      'variables': {'wormholeAddresses': wormholeAddresses, 'limit': limit, 'offset': offset},
    });

    final response = await _graphQlEndpoint.post(body: body);
    if (response.statusCode != 200) {
      throw Exception('GraphQL wormhole transfers query failed: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final transfers = responseBody['data']?['transfers'] as List<dynamic>?;
    if (transfers == null || transfers.isEmpty) return [];
    return transfers.map((t) => WormholeTransfer.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Return the subset of [nullifiers] that have been consumed on-chain.
  Future<Set<String>> getConsumedNullifiers(List<String> nullifiers) async {
    if (nullifiers.isEmpty) return {};

    final body = jsonEncode({
      'query': _nullifiersQuery,
      'variables': {'nullifiers': nullifiers},
    });

    final http.Response response = await _graphQlEndpoint.post(body: body);
    if (response.statusCode != 200) {
      throw Exception('GraphQL nullifiers query failed: ${response.statusCode}. Body: ${response.body}');
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final consumed = responseBody['data']?['wormholeNullifiers'] as List<dynamic>?;
    if (consumed == null || consumed.isEmpty) return {};
    return consumed.map((n) => (n as Map<String, dynamic>)['nullifier'] as String).toSet();
  }

  /// Get unspent transfers for [wormholeAddress] by filtering out consumed nullifiers.
  Future<List<WormholeTransfer>> getUnspentTransfers({
    required String wormholeAddress,
    required String secretHex,
    int limit = 100,
  }) async {
    final transfers = await getTransfersTo(wormholeAddress, limit: limit);
    if (transfers.isEmpty) return [];

    final hdWalletService = HdWalletService();
    final nullifierToTransfer = <String, WormholeTransfer>{};
    for (final transfer in transfers) {
      final nullifier = hdWalletService.computeNullifier(secretHex: secretHex, transferCount: transfer.transferCount);
      nullifierToTransfer[nullifier] = transfer;
    }

    final consumed = await getConsumedNullifiers(nullifierToTransfer.keys.toList());
    return nullifierToTransfer.entries.where((e) => !consumed.contains(e.key)).map((e) => e.value).toList();
  }

  /// Sum of unspent transfer amounts for [wormholeAddress].
  Future<BigInt> getUnspentBalance({required String wormholeAddress, required String secretHex}) async {
    final unspent = await getUnspentTransfers(wormholeAddress: wormholeAddress, secretHex: secretHex);
    return unspent.fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amount);
  }
}
