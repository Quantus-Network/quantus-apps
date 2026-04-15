import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:polkadart/polkadart.dart' show Hasher;
import 'package:polkadart/scale_codec.dart' as scale;
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/generated/planck/types/frame_system/event_record.dart';
import 'package:quantus_sdk/generated/planck/types/pallet_wormhole/pallet/event.dart'
    as wormhole_event;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_event.dart'
    as runtime_event;
import 'package:ss58/ss58.dart' as ss58;

final _log = log.withTag('TransferTracking');

/// Information about a mining reward transfer.
///
/// This is tracked locally when mining blocks so we can generate
/// withdrawal proofs later.
class TrackedTransfer {
  final String blockHash;
  final int blockNumber;
  final BigInt transferCount;
  final BigInt leafIndex;
  final BigInt amount;
  final String wormholeAddress;
  final String fundingAccount;
  final String? fundingAccountHex;
  final DateTime timestamp;

  const TrackedTransfer({
    required this.blockHash,
    required this.blockNumber,
    required this.transferCount,
    required this.leafIndex,
    required this.amount,
    required this.wormholeAddress,
    required this.fundingAccount,
    this.fundingAccountHex,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'blockHash': blockHash,
    'blockNumber': blockNumber,
    'transferCount': transferCount.toString(),
    'leafIndex': leafIndex.toString(),
    'amount': amount.toString(),
    'wormholeAddress': wormholeAddress,
    'fundingAccount': fundingAccount,
    'fundingAccountHex': fundingAccountHex,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TrackedTransfer.fromJson(Map<String, dynamic> json) {
    return TrackedTransfer(
      blockHash: json['blockHash'] as String,
      blockNumber: json['blockNumber'] as int,
      transferCount: BigInt.parse(json['transferCount'] as String),
      leafIndex: BigInt.parse(json['leafIndex'] as String? ?? '0'),
      amount: BigInt.parse(json['amount'] as String),
      wormholeAddress: json['wormholeAddress'] as String,
      fundingAccount: json['fundingAccount'] as String,
      fundingAccountHex: json['fundingAccountHex'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  TrackedTransfer copyWith({
    String? blockHash,
    int? blockNumber,
    BigInt? transferCount,
    BigInt? leafIndex,
    BigInt? amount,
    String? wormholeAddress,
    String? fundingAccount,
    String? fundingAccountHex,
    DateTime? timestamp,
  }) {
    return TrackedTransfer(
      blockHash: blockHash ?? this.blockHash,
      blockNumber: blockNumber ?? this.blockNumber,
      transferCount: transferCount ?? this.transferCount,
      leafIndex: leafIndex ?? this.leafIndex,
      amount: amount ?? this.amount,
      wormholeAddress: wormholeAddress ?? this.wormholeAddress,
      fundingAccount: fundingAccount ?? this.fundingAccount,
      fundingAccountHex: fundingAccountHex ?? this.fundingAccountHex,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() =>
      'TrackedTransfer(block: $blockNumber, count: $transferCount, amount: $amount)';
}

/// Service for tracking mining reward transfers.
///
/// This service monitors mined blocks for NativeTransferred events
/// and stores them locally for later use in withdrawal proof generation.
///
/// NOTE: This only tracks transfers that occur while the app is running.
/// Transfers made while the app is closed (e.g., direct transfers to the
/// wormhole address from another wallet) will NOT be tracked. Those would
/// require either:
/// - Scanning historical blocks on startup
/// - Using an indexer like Subsquid
/// - Manual entry of transfer details
class TransferTrackingService {
  // Singleton instance
  static final TransferTrackingService _instance =
      TransferTrackingService._internal();
  factory TransferTrackingService() => _instance;
  TransferTrackingService._internal();

  static const String _storageFileName = 'mining_transfers.json';

  String? _rpcUrl;
  bool _initialized = false;

  /// Whether the service has been initialized for the current session.
  bool get isInitialized => _initialized;

  /// Set of wormhole addresses to track transfers for.
  final Set<String> _trackedAddresses = {};
  int _lastProcessedBlock = 0;

  // In-memory cache of tracked transfers
  final Map<String, List<TrackedTransfer>> _transfersByAddress = {};

  /// Initialize the service with RPC URL and wormhole addresses to track.
  ///
  /// On dev chains, this clears any stale transfers from previous chain states.
  Future<void> initialize({
    required String rpcUrl,
    required Set<String> wormholeAddresses,
  }) async {
    _rpcUrl = rpcUrl;
    _trackedAddresses.clear();
    _trackedAddresses.addAll(wormholeAddresses);

    // On dev chains, clear stale transfers since the chain resets on restart
    if (await _isDevChain()) {
      _log.i('Development chain detected; clearing stale tracked transfers');
      await clearAllTransfers();
    }

    _initialized = true;
    _log.i(
      'Initialized transfer tracking for ${wormholeAddresses.length} addresses',
    );
  }

  /// Add a new address to track.
  void addTrackedAddress(String address) {
    _trackedAddresses.add(address);
    _log.i('Added address to tracking: $address');
  }

  /// Get all tracked addresses.
  Set<String> get trackedAddresses => Set.unmodifiable(_trackedAddresses);

  /// Load previously tracked transfers from disk.
  Future<void> loadFromDisk() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        _transfersByAddress.clear();
        final transfersData = data['transfers'] as Map<String, dynamic>?;
        if (transfersData != null) {
          for (final entry in transfersData.entries) {
            final address = entry.key;
            final transfers = (entry.value as List)
                .map((t) => TrackedTransfer.fromJson(t as Map<String, dynamic>))
                .toList();
            _transfersByAddress[address] = transfers;
          }
        }

        _lastProcessedBlock = data['lastProcessedBlock'] as int? ?? 0;
        _log.i(
          'Loaded ${_transfersByAddress.values.expand((t) => t).length} transfers from disk',
        );
      }
    } catch (e) {
      _log.e('Failed to load transfers from disk', error: e);
    }
  }

  /// Clear all tracked transfers and delete the storage file.
  Future<void> clearAllTransfers() async {
    _transfersByAddress.clear();
    _lastProcessedBlock = 0;
    _initialized = false;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        await file.delete();
        _log.i('Deleted tracked transfers file');
      }
    } catch (e) {
      _log.e('Failed to delete transfers file', error: e);
    }
  }

  /// Save tracked transfers to disk.
  Future<void> saveToDisk() async {
    try {
      final file = await _getStorageFile();
      final data = {
        'lastProcessedBlock': _lastProcessedBlock,
        'transfers': _transfersByAddress.map(
          (address, transfers) =>
              MapEntry(address, transfers.map((t) => t.toJson()).toList()),
        ),
      };
      await file.writeAsString(jsonEncode(data));
      _log.d('Saved transfers to disk');
    } catch (e) {
      _log.e('Failed to save transfers to disk', error: e);
    }
  }

  Future<File> _getStorageFile() async {
    final appDir = await getApplicationSupportDirectory();
    final quantusDir = Directory('${appDir.path}/.quantus');
    if (!await quantusDir.exists()) {
      await quantusDir.create(recursive: true);
    }
    return File('${quantusDir.path}/$_storageFileName');
  }

  /// Process a newly mined block to check for transfers.
  ///
  /// Call this when a new block is detected/mined.
  Future<void> processBlock(int blockNumber, String blockHash) async {
    _log.i('processBlock called: block=$blockNumber, hash=$blockHash');

    if (_rpcUrl == null || _trackedAddresses.isEmpty) {
      _log.w(
        'Service not initialized, skipping block $blockNumber (rpcUrl=$_rpcUrl, trackedAddresses=${_trackedAddresses.length})',
      );
      return;
    }

    // Skip if we've already processed this block
    if (blockNumber <= _lastProcessedBlock) {
      _log.d(
        'Skipping block $blockNumber (already processed up to $_lastProcessedBlock)',
      );
      return;
    }

    _log.i(
      'Processing block $blockNumber for transfers to ${_trackedAddresses.length} tracked addresses',
    );

    try {
      final transfers = await _getTransfersFromBlock(blockHash);
      _log.d(
        'Block $blockNumber has ${transfers.length} NativeTransferred events',
      );

      // Filter for transfers to any of our tracked wormhole addresses
      final relevantTransfers = transfers
          .where((t) => _trackedAddresses.contains(t.wormholeAddress))
          .toList();

      if (relevantTransfers.isNotEmpty) {
        _log.i(
          'Block $blockNumber: found ${relevantTransfers.length} transfer(s) to our tracked addresses',
        );

        // Add to in-memory cache, grouped by address
        for (final transfer in relevantTransfers) {
          final transferWithBlock = transfer.copyWith(blockNumber: blockNumber);
          _transfersByAddress
              .putIfAbsent(transfer.wormholeAddress, () => [])
              .add(transferWithBlock);
        }

        // Persist to disk
        await saveToDisk();
        _log.d('Saved ${relevantTransfers.length} transfers to disk');
      }

      _lastProcessedBlock = blockNumber;
    } catch (e, st) {
      _log.e('Failed to process block $blockNumber', error: e, stackTrace: st);
    }
  }

  /// Get all tracked transfers for a wormhole address.
  ///
  /// Returns a copy of the list to avoid concurrent modification issues.
  List<TrackedTransfer> getTransfers(String wormholeAddress) {
    return List.of(_transfersByAddress[wormholeAddress] ?? []);
  }

  /// Add a transfer to the tracking list.
  ///
  /// Used to import historical transfers from Subsquid.
  void addTrackedTransfer(TrackedTransfer transfer) {
    _transfersByAddress
        .putIfAbsent(transfer.wormholeAddress, () => [])
        .add(transfer);
  }

  /// Get all tracked transfers across all addresses.
  ///
  /// Returns a new list to avoid concurrent modification issues.
  List<TrackedTransfer> getAllTransfers() {
    return _transfersByAddress.values.expand((t) => List.of(t)).toList();
  }

  /// Get total tracked balance across all addresses.
  BigInt getTotalTrackedBalance() {
    return getAllTransfers().fold(BigInt.zero, (sum, t) => sum + t.amount);
  }

  /// Get unspent transfers for a wormhole address.
  ///
  /// Filters out transfers whose nullifiers have been consumed.
  Future<List<TrackedTransfer>> getUnspentTransfers({
    required String wormholeAddress,
    required String secretHex,
  }) async {
    final transfers = getTransfers(wormholeAddress);
    if (transfers.isEmpty) return [];

    final wormholeService = WormholeService();
    final unspent = <TrackedTransfer>[];

    for (final transfer in transfers) {
      final nullifier = wormholeService.computeNullifier(
        secretHex: secretHex,
        transferCount: transfer.transferCount,
      );

      final isConsumed = await _isNullifierConsumed(nullifier);
      if (!isConsumed) {
        unspent.add(transfer);
      }
    }

    return unspent;
  }

  /// Check if a nullifier has been consumed on chain.
  Future<bool> _isNullifierConsumed(String nullifierHex) async {
    if (_rpcUrl == null) return false;

    try {
      // Query Wormhole::UsedNullifiers storage
      // Storage key: twox128("Wormhole") ++ twox128("UsedNullifiers") ++ blake2_128_concat(nullifier)
      final nullifierBytes = nullifierHex.startsWith('0x')
          ? nullifierHex.substring(2)
          : nullifierHex;

      final modulePrefix = _twox128('Wormhole');
      final storagePrefix = _twox128('UsedNullifiers');
      final keyHash = _blake2128Concat(nullifierBytes);

      final storageKey = '0x$modulePrefix$storagePrefix$keyHash';

      final response = await http.post(
        Uri.parse(_rpcUrl!),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'state_getStorage',
          'params': [storageKey],
        }),
      );

      final result = jsonDecode(response.body);
      if (result['error'] != null) {
        _log.e('RPC error checking nullifier: ${result['error']}');
        return false;
      }

      // If storage exists and is not empty, nullifier is consumed
      final value = result['result'] as String?;
      final isConsumed = value != null && value != '0x' && value.isNotEmpty;

      // Only log consumed nullifiers (interesting case)
      if (isConsumed) {
        _log.i('Nullifier consumed: ${nullifierHex.substring(0, 18)}...');
      }

      return isConsumed;
    } catch (e) {
      _log.e('Failed to check nullifier', error: e);
      return false;
    }
  }

  // ============================================================
  // Helper functions for storage key computation
  // ============================================================

  /// Compute twox128 hash of a string (for Substrate storage key prefixes).
  String _twox128(String input) {
    final bytes = Uint8List.fromList(utf8.encode(input));
    final hash = Hasher.twoxx128.hash(bytes);
    return _bytesToHex(hash);
  }

  /// Compute blake2b-128 hash concatenated with input (for Substrate storage keys).
  /// Returns: blake2b_128(input) ++ input
  String _blake2128Concat(String hexInput) {
    final bytes = _hexToBytes(hexInput);
    final hash = Hasher.blake2b128.hash(bytes);
    return _bytesToHex(hash) + _bytesToHex(bytes);
  }

  /// Get transfers from a block by querying events.
  Future<List<TrackedTransfer>> _getTransfersFromBlock(String blockHash) async {
    if (_rpcUrl == null) {
      _log.w('_getTransfersFromBlock: rpcUrl is null');
      return [];
    }

    try {
      // Query System::Events storage at the block
      _log.d('Fetching events for block $blockHash from $_rpcUrl');
      final eventsHex = await _getBlockEvents(blockHash);
      if (eventsHex == null || eventsHex.isEmpty) {
        _log.d('No events found for block $blockHash');
        return [];
      }

      // Events data received (${eventsHex.length} chars)

      // Decode events and extract NativeTransferred
      return _decodeNativeTransferredEvents(eventsHex, blockHash);
    } catch (e, st) {
      _log.e('Failed to get transfers from block', error: e, stackTrace: st);
      return [];
    }
  }

  /// Get raw events storage for a block.
  Future<String?> _getBlockEvents(String blockHash) async {
    // Storage key for System::Events
    // twox128("System") ++ twox128("Events")
    const storageKey =
        '0x26aa394eea5630e07c48ae0c9558cef780d41e5e16056765bc8461851072c9d7';

    final response = await http.post(
      Uri.parse(_rpcUrl!),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'state_getStorage',
        'params': [storageKey, blockHash],
      }),
    );

    final result = jsonDecode(response.body);
    if (result['error'] != null) {
      _log.e('RPC error: ${result['error']}');
      return null;
    }

    return result['result'] as String?;
  }

  /// Decode NativeTransferred events from raw events data using generated Polkadart types.
  ///
  /// The events are SCALE-encoded as `Vec<EventRecord<RuntimeEvent, H256>>`.
  /// We look for Wormhole::NativeTransferred events.
  List<TrackedTransfer> _decodeNativeTransferredEvents(
    String eventsHex,
    String blockHash,
  ) {
    final transfers = <TrackedTransfer>[];

    try {
      final bytes = _hexToBytes(eventsHex);
      final input = scale.ByteInput(bytes);

      // Decode Vec<EventRecord>
      final numEvents = scale.CompactCodec.codec.decode(input);

      for (var i = 0; i < numEvents; i++) {
        try {
          // Use the generated EventRecord codec to decode each event
          final eventRecord = EventRecord.decode(input);

          // Check if this is a Wormhole pallet event
          // Note: The Wormhole pallet emits NativeTransferred for ALL transfers
          // into wormhole-compatible addresses (which are indistinguishable from
          // normal addresses on-chain). We filter by our tracked addresses later.
          final event = eventRecord.event;

          if (event is runtime_event.Wormhole) {
            final wormholeEvent = event.value0;

            // Check if it's a NativeTransferred event (emitted for deposits into any address)
            if (wormholeEvent is wormhole_event.NativeTransferred) {
              final toSs58 = _accountIdToSs58(
                Uint8List.fromList(wormholeEvent.to),
              );
              final fromSs58 = _accountIdToSs58(
                Uint8List.fromList(wormholeEvent.from),
              );

              transfers.add(
                TrackedTransfer(
                  blockHash: blockHash,
                  blockNumber: 0, // Will be filled in by caller
                  transferCount: wormholeEvent.transferCount,
                  leafIndex: wormholeEvent.leafIndex,
                  amount: wormholeEvent.amount,
                  wormholeAddress: toSs58,
                  fundingAccount: fromSs58,
                  fundingAccountHex:
                      '0x${_bytesToHex(Uint8List.fromList(wormholeEvent.from))}',
                  timestamp: DateTime.now(),
                ),
              );
            }
          }
        } catch (e) {
          _log.w('Failed to decode event $i: $e');
          // Continue trying to decode remaining events
        }
      }
    } catch (e) {
      _log.e('Failed to decode events', error: e);
    }

    return transfers;
  }

  /// Convert AccountId32 bytes to SS58 address with Quantus prefix (189).
  String _accountIdToSs58(Uint8List accountId) {
    // Use ss58 package to encode with Quantus network prefix (189)
    const quantusPrefix = 189;
    return ss58.Address(prefix: quantusPrefix, pubkey: accountId).encode();
  }

  Uint8List _hexToBytes(String hex) {
    final str = hex.startsWith('0x') ? hex.substring(2) : hex;
    final result = Uint8List(str.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(str.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> _isDevChain() async {
    if (_rpcUrl == null) return false;

    final response = await http.post(
      Uri.parse(_rpcUrl!),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'system_chain',
        'params': [],
      }),
    );

    final result = jsonDecode(response.body);
    if (result['error'] != null) {
      return false;
    }

    final chainName = ((result['result'] as String?) ?? '').toLowerCase();
    return chainName.contains('development') || chainName.contains('dev');
  }
}
