import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/wormhole_service.dart';

/// A wormhole transfer that can be spent with a ZK proof.
///
/// This represents a deposit to a wormhole address that has not yet been
/// spent (no nullifier revealed on-chain).
class WormholeTransfer {
  /// Unique identifier for this transfer.
  final String id;

  /// The wormhole address that received the funds.
  final String wormholeAddress;

  /// The account that sent the funds (funding account).
  final String fromAddress;

  /// Amount in planck (12 decimal places).
  final BigInt amount;

  /// Transfer count from the Wormhole pallet - required for ZK proof generation.
  final BigInt transferCount;

  /// Block number where the transfer was recorded.
  final int blockNumber;

  /// Block hash where the transfer was recorded.
  final String blockHash;

  /// Timestamp of the transfer.
  final DateTime timestamp;

  const WormholeTransfer({
    required this.id,
    required this.wormholeAddress,
    required this.fromAddress,
    required this.amount,
    required this.transferCount,
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
      blockNumber: block?['height'] as int? ?? 0,
      blockHash: block?['hash'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convert to WormholeUtxo for proof generation.
  ///
  /// [secretHex] should be the secret derived from the mnemonic for this
  /// wormhole address.
  WormholeUtxo toUtxo(String secretHex) {
    return WormholeUtxo(
      secretHex: secretHex,
      amount: amount,
      transferCount: transferCount,
      fundingAccountHex: _addressToHex(fromAddress),
      blockHashHex: blockHash.startsWith('0x') ? blockHash : '0x$blockHash',
    );
  }

  static String _addressToHex(String ss58Address) {
    final bytes = crypto.ss58ToAccountId(s: ss58Address);
    return '0x${hex.encode(bytes)}';
  }

  @override
  String toString() {
    return 'WormholeTransfer{id: $id, to: $wormholeAddress, from: $fromAddress, '
        'amount: $amount, transferCount: $transferCount, block: $blockNumber}';
  }
}

/// Service for querying wormhole UTXOs from Subsquid.
///
/// This service queries the Subsquid indexer to find transfers to wormhole
/// addresses that have not been spent (no nullifier revealed on-chain).
class WormholeUtxoService {
  final GraphQlEndpointService _graphQlEndpoint = GraphQlEndpointService();

  /// GraphQL query to fetch wormhole transfers by recipient address.
  ///
  /// Only returns transfers with source=WORMHOLE that have a transferCount
  /// (required for ZK proof generation).
  static const String _transfersToWormholeQuery = r'''
query WormholeTransfers($wormholeAddress: String!, $limit: Int!, $offset: Int!) {
  transfers(
    limit: $limit
    offset: $offset
    where: {
      to: { id_eq: $wormholeAddress }
      source_eq: WORMHOLE
      transferCount_isNull: false
    }
    orderBy: timestamp_DESC
  ) {
    id
    from { id }
    to { id }
    amount
    transferCount
    timestamp
    block {
      height
      hash
    }
  }
}''';

  /// GraphQL query to check if nullifiers have been consumed.
  static const String _nullifiersQuery = r'''
query CheckNullifiers($nullifiers: [String!]!) {
  wormholeNullifiers(
    where: { nullifier_in: $nullifiers }
  ) {
    nullifier
  }
}''';

  /// GraphQL query to fetch transfers by multiple wormhole addresses.
  static const String _transfersToMultipleQuery = r'''
query WormholeTransfersMultiple($wormholeAddresses: [String!]!, $limit: Int!, $offset: Int!) {
  transfers(
    limit: $limit
    offset: $offset
    where: {
      to: { id_in: $wormholeAddresses }
      source_eq: WORMHOLE
      transferCount_isNull: false
    }
    orderBy: timestamp_DESC
  ) {
    id
    from { id }
    to { id }
    amount
    transferCount
    timestamp
    block {
      height
      hash
    }
  }
}''';

  /// Fetch all wormhole transfers to an address.
  ///
  /// This returns all transfers that have been made to the wormhole address,
  /// including those that may have already been spent.
  ///
  /// Use [getUnspentUtxos] to filter out spent transfers.
  Future<List<WormholeTransfer>> getTransfersTo(String wormholeAddress, {int limit = 100, int offset = 0}) async {
    final body = jsonEncode({
      'query': _transfersToWormholeQuery,
      'variables': {'wormholeAddress': wormholeAddress, 'limit': limit, 'offset': offset},
    });

    final http.Response response = await _graphQlEndpoint.post(body: body);

    if (response.statusCode != 200) {
      throw Exception(
        'GraphQL wormhole transfers query failed: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final transfers = responseBody['data']?['transfers'] as List<dynamic>?;
    if (transfers == null || transfers.isEmpty) {
      return [];
    }

    return transfers.map((t) => WormholeTransfer.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Fetch transfers to multiple wormhole addresses.
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

    final http.Response response = await _graphQlEndpoint.post(body: body);

    if (response.statusCode != 200) {
      throw Exception(
        'GraphQL wormhole transfers query failed: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final transfers = responseBody['data']?['transfers'] as List<dynamic>?;
    if (transfers == null || transfers.isEmpty) {
      return [];
    }

    return transfers.map((t) => WormholeTransfer.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Check which nullifiers have been consumed on-chain.
  ///
  /// Returns a set of nullifier hex strings that have been spent.
  Future<Set<String>> getConsumedNullifiers(List<String> nullifiers) async {
    if (nullifiers.isEmpty) return {};

    final body = jsonEncode({
      'query': _nullifiersQuery,
      'variables': {'nullifiers': nullifiers},
    });

    final http.Response response = await _graphQlEndpoint.post(body: body);

    if (response.statusCode != 200) {
      throw Exception(
        'GraphQL nullifiers query failed: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (responseBody['errors'] != null) {
      throw Exception('GraphQL errors: ${responseBody['errors']}');
    }

    final consumed = responseBody['data']?['wormholeNullifiers'] as List<dynamic>?;
    if (consumed == null || consumed.isEmpty) {
      return {};
    }

    return consumed.map((n) => (n as Map<String, dynamic>)['nullifier'] as String).toSet();
  }

  /// Get unspent UTXOs for a wormhole address.
  ///
  /// This fetches all transfers to the address and filters out those whose
  /// nullifiers have already been consumed on-chain.
  ///
  /// [secretHex] is used to compute nullifiers for each transfer.
  Future<List<WormholeTransfer>> getUnspentTransfers({
    required String wormholeAddress,
    required String secretHex,
    int limit = 100,
  }) async {
    // Fetch all transfers to this address
    final transfers = await getTransfersTo(wormholeAddress, limit: limit);
    if (transfers.isEmpty) return [];

    // Compute nullifiers for each transfer
    final wormholeService = WormholeService();
    final nullifierToTransfer = <String, WormholeTransfer>{};

    for (final transfer in transfers) {
      final nullifier = wormholeService.computeNullifier(secretHex: secretHex, transferCount: transfer.transferCount);
      nullifierToTransfer[nullifier] = transfer;
    }

    // Check which nullifiers have been consumed
    final consumedNullifiers = await getConsumedNullifiers(nullifierToTransfer.keys.toList());

    // Return transfers whose nullifiers have NOT been consumed
    return nullifierToTransfer.entries
        .where((entry) => !consumedNullifiers.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
  }

  /// Get total unspent balance for a wormhole address.
  Future<BigInt> getUnspentBalance({required String wormholeAddress, required String secretHex}) async {
    final unspent = await getUnspentTransfers(wormholeAddress: wormholeAddress, secretHex: secretHex);

    return unspent.fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amount);
  }

  /// Get unspent UTXOs ready for proof generation.
  ///
  /// Returns [WormholeUtxo] objects that can be passed directly to
  /// [WormholeProofGenerator.generateProof].
  Future<List<WormholeUtxo>> getUnspentUtxos({
    required String wormholeAddress,
    required String secretHex,
    int limit = 100,
  }) async {
    final transfers = await getUnspentTransfers(wormholeAddress: wormholeAddress, secretHex: secretHex, limit: limit);

    return transfers.map((t) => t.toUtxo(secretHex)).toList();
  }
}
