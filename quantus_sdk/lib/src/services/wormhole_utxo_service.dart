import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart' show protected, visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole_ffi;
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

class WormholeTransfer {
  final String id;
  final int blockHeight;
  final DateTime timestamp;
  final String fromId;
  final String toId;
  final BigInt amount;
  final String toHash;
  final BigInt leafIndex;
  final BigInt transferCount;

  /// Hash of the extrinsic that paid this transfer; empty for mining rewards
  /// and genesis leaves, which no extrinsic produces.
  final String extrinsicId;

  const WormholeTransfer({
    required this.id,
    required this.blockHeight,
    required this.timestamp,
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.toHash,
    required this.leafIndex,
    required this.transferCount,
    required this.extrinsicId,
  });

  factory WormholeTransfer.fromJson(Map<String, dynamic> json) {
    return WormholeTransfer(
      id: json['id'] as String,
      blockHeight: json['blockHeight'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fromId: json['fromId'] as String? ?? '',
      toId: json['toId'] as String? ?? '',
      amount: BigInt.parse(json['amount'] as String),
      toHash: json['toHash'] as String? ?? '',
      leafIndex: BigInt.parse(json['leafIndex'] as String),
      transferCount: BigInt.parse(json['transferCount'] as String),
      extrinsicId: json['extrinsicId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blockHeight': blockHeight,
    'timestamp': timestamp.toIso8601String(),
    'fromId': fromId,
    'toId': toId,
    'amount': amount.toString(),
    'toHash': toHash,
    'leafIndex': leafIndex.toString(),
    'transferCount': transferCount.toString(),
    'extrinsicId': extrinsicId,
  };

  @override
  String toString() =>
      'WormholeTransfer{id: $id, block: $blockHeight, amount: $amount, '
      'leafIndex: $leafIndex, transferCount: $transferCount}';
}

/// Position of the last row already fetched in the `(block_height asc, id asc)`
/// transfer order; the next page starts strictly after it.
class WormholeTransferCursor {
  final int blockHeight;
  final String id;

  const WormholeTransferCursor({required this.blockHeight, required this.id});

  WormholeTransferCursor.afterTransfer(WormholeTransfer transfer)
    : this(blockHeight: transfer.blockHeight, id: transfer.id);

  @override
  String toString() => 'WormholeTransferCursor(block: $blockHeight, id: $id)';
}

/// One HD-derived wormhole address (index in the wormhole derivation sequence,
/// with [isChange] selecting the change branch of the derivation path) together
/// with the secret needed to compute nullifiers and spend proofs.
///
/// [secretHex] is required on input to [WormholeUtxoService.getUnspentUtxos]
/// (nullifier computation) but is always blanked on the [WormholeUtxo.owner]
/// of returned UTXOs: UTXOs are kept in long-lived app state, and secrets are
/// never cached — spenders re-derive from [index]/[isChange] when needed (M11).
class WormholeAddressInfo {
  final int index;
  final bool isChange;
  final String address;
  final String secretHex;

  const WormholeAddressInfo({
    required this.index,
    this.isChange = false,
    required this.address,
    required this.secretHex,
  });
}

/// A wormhole transfer together with the address that owns it.
class WormholeUtxo {
  final WormholeTransfer transfer;
  final WormholeAddressInfo owner;
  final String nullifierHex;

  const WormholeUtxo({required this.transfer, required this.owner, required this.nullifierHex});

  BigInt get amount => transfer.amount;
}

/// One exit of a wormhole proof. [id] is also the id of the [WormholeTransfer]
/// the exit created for its recipient.
class WormholeOutput {
  final String id;
  final String exitAccountId;
  final BigInt amount;

  const WormholeOutput({required this.id, required this.exitAccountId, required this.amount});

  factory WormholeOutput.fromJson(Map<String, dynamic> json) => WormholeOutput(
    id: json['id'] as String,
    exitAccountId: json['exitAccountId'] as String,
    amount: BigInt.parse(json['amount'] as String),
  );

  Map<String, dynamic> toJson() => {'id': id, 'exitAccountId': exitAccountId, 'amount': amount.toString()};
}

/// The proof extrinsic that consumed a nullifier, with every exit it paid.
/// [call] is the pallet call that settled it: a private batch is one client's
/// proof, a public batch bundles several clients' private batches.
class WormholeSpend {
  static const String privateBatchCall = 'verify_private_batch';

  /// [privateBatchCall] and its name before the public batch existed
  /// (renamed in the runtime on 2026-07-22; only testnet history has it).
  static const Set<String> privateBatchCalls = {privateBatchCall, 'verify_aggregated_proof'};

  final String extrinsicId;
  final int blockHeight;
  final DateTime timestamp;
  final String call;
  final List<WormholeOutput> outputs;

  const WormholeSpend({
    required this.extrinsicId,
    required this.blockHeight,
    required this.timestamp,
    required this.call,
    required this.outputs,
  });

  /// Chain order of this spend: exit ids are `<block>-<hash>-<event index>`,
  /// zero-padded, so the earliest one sorts spends across and within blocks.
  String get position => outputs.map((o) => o.id).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);

  factory WormholeSpend.fromJson(Map<String, dynamic> json) => WormholeSpend(
    extrinsicId: json['extrinsicId'] as String,
    blockHeight: json['blockHeight'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
    call: json['call'] as String,
    outputs: [for (final o in json['outputs'] as List<dynamic>) WormholeOutput.fromJson(o as Map<String, dynamic>)],
  );

  Map<String, dynamic> toJson() => {
    'extrinsicId': extrinsicId,
    'blockHeight': blockHeight,
    'timestamp': timestamp.toIso8601String(),
    'call': call,
    'outputs': outputs.map((o) => o.toJson()).toList(),
  };
}

/// Everything the indexer knows about a set of wormhole addresses: every
/// transfer they ever received and, for each spent one, the spend that
/// consumed it (keyed by nullifier hex).
class WormholeUtxoResult {
  final List<WormholeUtxo> received;
  final Map<String, WormholeSpend> spends;

  const WormholeUtxoResult({required this.received, required this.spends});

  List<WormholeUtxo> get utxos => received.where((u) => !spends.containsKey(u.nullifierHex)).toList();
}

typedef WormholeProgressCallback = void Function(int phase, int completed, {int? total});

/// Returns true if the caller wants the in-progress operation to abort.
typedef IsCancelledCallback = bool Function();

/// Thrown when an [IsCancelledCallback] returns true mid-flight.
class WormholeOperationCancelled implements Exception {
  const WormholeOperationCancelled();
  @override
  String toString() => 'Wormhole operation cancelled by caller';
}

class WormholeUtxoService {
  @visibleForTesting
  static const int transferPageSize = 300;

  /// Generation of both on-disk caches; bump on any format change. v3 keys the
  /// files by network as well as address, so Planck-era files are dropped
  /// instead of being read against mainnet; v6 records each transfer's
  /// timestamp and extrinsic and each spent nullifier's spend.
  @visibleForTesting
  static const int cacheVersion = 6;
  static const int _nullifierBatchSize = 300;
  static const int _reorgDepth = 180;

  static const String _transferSelection = r'''
    id
    blockHeight: block_height
    timestamp
    fromId: from_id
    toId: to_id
    amount
    toHash: to_hash
    leafIndex: leaf_index
    transferCount: transfer_count
    extrinsicId: extrinsic_id''';

  /// First page of inbound wormhole transfers to one address above [afterBlock].
  ///
  /// Filters and orders on scalar columns only so Postgres can walk the
  /// `(to_id, block_height, id)` index in output order; a nested `to { id }`
  /// or `block { height }` predicate would force a join and a sort.
  ///
  /// One address per query on purpose: Hasura renders `_in` as
  /// `to_id = ANY(array)`, and with `ORDER BY block_height, id` the planner
  /// then refuses the composite index (live Planck: parallel seq scan over
  /// 2.4M rows + top-N sort, ~900ms, for a 1M-row inbox) whereas `_eq` is an
  /// index-only range scan that stops at [transferPageSize] rows (~2ms).
  @visibleForTesting
  static const String transfersToAddressQuery =
      '''
query TransfersToAddress(\$to: String!, \$limit: Int!, \$afterBlock: Int!) {
  transfers: transfer(
    where: { to_id: {_eq: \$to}, block_height: {_gt: \$afterBlock} }
    order_by: [{block_height: asc}, {id: asc}]
    limit: \$limit
  ) {
$_transferSelection
  }
}''';

  /// Subsequent pages: rows strictly after the `(block_height, id)` cursor.
  /// The cursor row is itself above `afterBlock`, so that bound is implied.
  ///
  /// Written as `height >= h AND NOT (height = h AND id <= id)` rather than an
  /// `_or` so the planner keeps a single ordered index range scan instead of a
  /// BitmapOr followed by a sort.
  @visibleForTesting
  static const String transfersToAddressAfterQuery =
      '''
query TransfersToAddressAfter(\$to: String!, \$limit: Int!, \$cursorHeight: Int!, \$cursorId: String!) {
  transfers: transfer(
    where: {
      to_id: {_eq: \$to}
      block_height: {_gte: \$cursorHeight}
      _not: {block_height: {_eq: \$cursorHeight}, id: {_lte: \$cursorId}}
    }
    order_by: [{block_height: asc}, {id: asc}]
    limit: \$limit
  ) {
$_transferSelection
  }
}''';

  final GraphQlEndpointService _graphQlEndpoint;
  final RpcEndpointService _rpcEndpoint;

  /// Defaults to the app-wide endpoints; pass both to discover on another chain.
  WormholeUtxoService({GraphQlEndpointService? graphQl, RpcEndpointService? rpc})
    : _graphQlEndpoint = graphQl ?? GraphQlEndpointService(),
      _rpcEndpoint = rpc ?? RpcEndpointService();

  static void _log(String msg) => quantusPrint('[WormholeUtxo] $msg');

  static String _addressHash(Uint8List raw32) => wormhole_ffi.computeAddressHashHex(rawAddress: raw32);

  static String _addressHashOf(String ss58Address) => _addressHash(Uint8List.fromList(getAccountId32(ss58Address)));

  static void _throwIfCancelled(IsCancelledCallback? isCancelled) {
    if (isCancelled?.call() == true) throw const WormholeOperationCancelled();
  }

  // --- Cache ---

  static const int _idLength = 16;

  String? _networkId;

  /// Namespace of this chain's caches: the first 16 hex chars of its genesis
  /// hash, so a chain switch never reads another chain's transfers, scan
  /// height, or spent nullifiers. Fetched once per instance.
  @visibleForTesting
  Future<String> networkId() async {
    if (_networkId != null) return _networkId!;
    final result = await _rpc('chain_getBlockHash', [0]);
    final hash = result is String ? result.replaceFirst('0x', '') : '';
    if (hash.length < _idLength) throw Exception('chain_getBlockHash(0) returned no genesis hash: $result');
    return _networkId = hash.substring(0, _idLength);
  }

  static String _cachePrefix(String addressHash) => addressHash.substring(0, _idLength);

  static String _cacheName(String kind, String networkId, String prefix) =>
      'wormhole_${kind}_v${cacheVersion}_${networkId}_$prefix.json';

  static bool _isCacheFileFor(String name, String prefix) =>
      (name.startsWith('wormhole_cache_') || name.startsWith('wormhole_nullifiers')) && name.endsWith('_$prefix.json');

  static final RegExp _currentGeneration = RegExp(
    '^wormhole_(cache|nullifiers)_v${cacheVersion}_[0-9a-fA-F]{$_idLength}_[0-9a-fA-F]{$_idLength}\\.json\$',
  );

  static String _fileName(FileSystemEntity entity) =>
      entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last;

  Future<File> _cacheFile(String kind, String addressHash) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/${_cacheName(kind, await networkId(), _cachePrefix(addressHash))}');
  }

  /// Deletes every cache file of [addressHash] from an earlier generation.
  /// Current-generation files of other networks stay, so switching chains
  /// back and forth does not rescan.
  @visibleForTesting
  static Future<void> deleteStaleCaches(String addressHash) async {
    try {
      final prefix = _cachePrefix(addressHash);
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = _fileName(entity);
        if (_isCacheFileFor(name, prefix) && !_currentGeneration.hasMatch(name)) {
          await entity.delete();
          _log('Deleted stale cache: $name');
        }
      }
    } catch (e) {
      _log('Stale cache delete failed (non-fatal): $e');
    }
  }

  Future<_TransferCache> _loadTransferCache(String addressHash) async {
    await deleteStaleCaches(addressHash);
    try {
      final file = await _cacheFile('cache', addressHash);
      if (!await file.exists()) return _TransferCache.empty();
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _TransferCache.fromJson(json);
    } catch (e) {
      _log('Transfer cache load failed: $e');
      return _TransferCache.empty();
    }
  }

  @visibleForTesting
  Future<int> cachedTransferHeight(String addressHash) async => (await _loadTransferCache(addressHash)).cachedUpToBlock;

  Future<void> _saveTransferCache(String addressHash, _TransferCache cache) async {
    try {
      final file = await _cacheFile('cache', addressHash);
      await file.writeAsString(jsonEncode(cache.toJson()));
      _log('Transfer cache saved: ${cache.transfers.length} transfers up to block ${cache.cachedUpToBlock}');
    } catch (e) {
      _log('Transfer cache save failed: $e');
    }
  }

  @visibleForTesting
  Future<Map<String, WormholeSpend>> loadSpentNullifiers(String addressHash) async {
    await deleteStaleCaches(addressHash);
    try {
      final file = await _cacheFile('nullifiers', addressHash);
      if (!await file.exists()) return {};
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json.map((nullifier, spend) => MapEntry(nullifier, WormholeSpend.fromJson(spend as Map<String, dynamic>)));
    } catch (e) {
      _log('Nullifier cache load failed: $e');
      return {};
    }
  }

  @visibleForTesting
  Future<void> saveSpentNullifiers(String addressHash, Map<String, WormholeSpend> spent) async {
    try {
      final file = await _cacheFile('nullifiers', addressHash);
      await file.writeAsString(jsonEncode(spent.map((nullifier, spend) => MapEntry(nullifier, spend.toJson()))));
      _log('Nullifier cache saved: ${spent.length} spent nullifiers');
    } catch (e) {
      _log('Nullifier cache save failed: $e');
    }
  }

  /// Deletes transfer / nullifier caches only for the given [addresses].
  static Future<void> clearCachesForAddresses(List<String> addresses) async {
    try {
      final prefixes = addresses.map((a) => _cachePrefix(_addressHashOf(a))).toSet();
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) return;
      var deleted = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = _fileName(entity);
        if (prefixes.any((p) => _isCacheFileFor(name, p))) {
          await entity.delete();
          deleted++;
        }
      }
      _log('clearCachesForAddresses: deleted $deleted file(s) for ${addresses.length} addresses');
    } catch (e) {
      _log('clearCachesForAddresses failed (non-fatal): $e');
    }
  }

  /// Deletes every on-disk wormhole transfer / nullifier cache. Call on logout
  /// so a new wallet never reuses another wallet's UTXO discovery state.
  static Future<void> clearAllCaches() async {
    try {
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) return;
      var deleted = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = _fileName(entity);
        if (name.startsWith('wormhole_cache_') || name.startsWith('wormhole_nullifiers')) {
          await entity.delete();
          deleted++;
        }
      }
      _log('clearAllCaches: deleted $deleted file(s)');
    } catch (e) {
      _log('clearAllCaches failed (non-fatal): $e');
    }
  }

  // --- RPC ---

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params});
    final response = await _rpcEndpoint.post(body: body);
    if (response.statusCode != 200) {
      throw Exception('$method HTTP ${response.statusCode}: ${response.body}');
    }
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['error'] != null) {
      throw Exception('$method RPC error: ${parsed['error']}');
    }
    return parsed['result'];
  }

  /// Current chain head (best block) height. Throws if RPC fails — callers must
  /// not advance the cache from a fabricated value.
  Future<int> _getChainHeight() async {
    final result = await _rpc('chain_getHeader', []);
    final numberHex = result is Map ? result['number'] as String? : null;
    if (numberHex == null) {
      throw Exception('chain_getHeader returned no number: $result');
    }
    final height = int.parse(numberHex.replaceFirst('0x', ''), radix: 16);
    _log('Chain height from RPC: $height');
    return height;
  }

  // --- GraphQL queries ---

  /// Posts [query] and returns the rows of its [field]; HTTP and GraphQL
  /// errors throw.
  Future<List<Map<String, dynamic>>> _graphQlRows(
    String label,
    String query,
    Map<String, dynamic> variables,
    String field,
  ) async {
    final sw = Stopwatch()..start();
    final response = await _graphQlEndpoint.post(body: jsonEncode({'query': query, 'variables': variables}));
    _log('$label query: status=${response.statusCode} elapsed=${sw.elapsedMilliseconds}ms');
    if (response.statusCode != 200) {
      _log('$label query FAILED: ${response.body}');
      throw Exception('Subsquid $label request failed ${response.statusCode}: ${response.body}');
    }
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['errors'] != null) {
      final msgs = (parsed['errors'] as List).map((e) => (e as Map)['message']).join('; ');
      _log('$label query GraphQL errors: $msgs');
      throw Exception('GraphQL errors: $msgs');
    }
    return ((parsed['data']?[field] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// One page of transfers to [toAddress] above [afterBlock], in
  /// `(block_height, id)` order. With [after] set, only rows strictly after
  /// that cursor are returned.
  @protected
  @visibleForTesting
  Future<List<WormholeTransfer>> queryTransfersPage({
    required String toAddress,
    required int afterBlock,
    WormholeTransferCursor? after,
    int limit = transferPageSize,
  }) async {
    final String document;
    final variables = <String, dynamic>{'to': toAddress, 'limit': limit};
    if (after == null) {
      document = transfersToAddressQuery;
      variables['afterBlock'] = afterBlock;
    } else {
      document = transfersToAddressAfterQuery;
      variables['cursorHeight'] = after.blockHeight;
      variables['cursorId'] = after.id;
    }

    _log('transfers query: limit=$limit afterBlock=$afterBlock cursor=$after');
    final rows = await _graphQlRows('transfers', document, variables, 'transfers');
    _log('transfers query: received ${rows.length} transfers');
    return rows.map(WormholeTransfer.fromJson).toList();
  }

  /// Walks every transfer to [toAddress] above [afterBlock] by following the
  /// `(block_height, id)` cursor of each full page.
  @visibleForTesting
  Future<List<WormholeTransfer>> fetchAllTransfers({
    required String toAddress,
    required int afterBlock,
    void Function(int fetched)? onFetched,
    IsCancelledCallback? isCancelled,
  }) async {
    final totalSw = Stopwatch()..start();
    final all = <WormholeTransfer>[];
    WormholeTransferCursor? cursor;
    int pageNum = 0;
    while (true) {
      _throwIfCancelled(isCancelled);
      pageNum++;
      final page = await queryTransfersPage(
        toAddress: toAddress,
        afterBlock: afterBlock,
        after: cursor,
        limit: transferPageSize,
      );
      all.addAll(page);
      onFetched?.call(all.length);
      _log(
        'Page $pageNum: got ${page.length} transfers, total so far: ${all.length} (${totalSw.elapsedMilliseconds}ms elapsed)',
      );
      if (page.length < transferPageSize) break;
      cursor = WormholeTransferCursor.afterTransfer(page.last);
    }
    _log('Fetched ${all.length} total transfers in ${totalSw.elapsedMilliseconds}ms ($pageNum pages)');
    return all;
  }

  // --- Nullifiers ---

  /// Looks up which of [nullifierHashes] are already spent on-chain. Returns a
  /// map from nullifier hash to the spend that consumed it; its block height
  /// lets callers decide whether the entry is reorg-safe to persist.
  Future<Map<String, WormholeSpend>> _querySpentNullifierHashes(List<String> nullifierHashes) async {
    const query = r'''
query SpentNullifiers($hashes: [String!]!) {
  wormholeNullifiers: wormhole_nullifier(where: { nullifier_hash: {_in: $hashes } }, limit: 1000) {
    nullifierHash: nullifier_hash
    extrinsicId: wormhole_extrinsic_id
    timestamp
    block { height }
    wormholeExtrinsic { extrinsic { call } outputs { id exitAccountId: exit_account_id amount } }
  }
}''';

    _log('nullifiers query: ${nullifierHashes.length} hashes');
    final rows = await _graphQlRows('nullifiers', query, {'hashes': nullifierHashes}, 'wormholeNullifiers');
    final found = <String, WormholeSpend>{};
    for (final m in rows) {
      final extrinsic = m['wormholeExtrinsic'] as Map<String, dynamic>;
      found[m['nullifierHash'] as String] = WormholeSpend(
        extrinsicId: m['extrinsicId'] as String,
        blockHeight: (m['block'] as Map<String, dynamic>)['height'] as int,
        timestamp: DateTime.parse(m['timestamp'] as String),
        call: (extrinsic['extrinsic'] as Map<String, dynamic>)['call'] as String,
        outputs: [
          for (final o in extrinsic['outputs'] as List<dynamic>) WormholeOutput.fromJson(o as Map<String, dynamic>),
        ],
      );
    }
    _log('nullifiers query: ${found.length} spent out of ${nullifierHashes.length} queried');
    return found;
  }

  /// Returns a map from nullifier hex to the spend that consumed it. Callers
  /// are responsible for deciding which entries are reorg-safe to persist
  /// (see `getUnspentUtxos`).
  @visibleForTesting
  Future<Map<String, WormholeSpend>> checkNullifiersSpent(
    List<(String nullifierHex, String nullifierHash)> nullifiers, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    if (nullifiers.isEmpty) return {};

    final totalSw = Stopwatch()..start();
    final hashToNullifier = <String, String>{};
    for (final (nulHex, nulHash) in nullifiers) {
      hashToNullifier[nulHash] = nulHex;
    }

    final allHashes = hashToNullifier.keys.toList();
    final spent = <String, WormholeSpend>{};
    onProgress?.call(3, 0, total: nullifiers.length);

    for (int i = 0; i < allHashes.length; i += _nullifierBatchSize) {
      _throwIfCancelled(isCancelled);
      final batch = allHashes.sublist(i, (i + _nullifierBatchSize).clamp(0, allHashes.length));
      final batchNum = (i ~/ _nullifierBatchSize) + 1;
      final spentBatch = await _querySpentNullifierHashes(batch);
      for (final entry in spentBatch.entries) {
        final nulHex = hashToNullifier[entry.key];
        if (nulHex != null) spent[nulHex] = entry.value;
      }
      final checked = (i + batch.length).clamp(0, nullifiers.length);
      onProgress?.call(3, checked, total: nullifiers.length);
      _log(
        'Nullifier batch $batchNum: checked ${batch.length}, total checked: $checked (${totalSw.elapsedMilliseconds}ms elapsed)',
      );
    }

    _log('Nullifiers: ${spent.length} spent out of ${nullifiers.length} (${totalSw.elapsedMilliseconds}ms total)');
    return spent;
  }

  // --- Public API ---

  /// Fetches every wormhole transfer ever sent to any of [addresses] and
  /// returns them grouped by address, along with the reorg-safe block cutoff
  /// used for caching.
  ///
  /// Each address keeps its own on-disk cache and is paged with its own `_eq`
  /// query (see [transfersToAddressQuery] for why addresses are not batched
  /// into one `_in`). The cache only advances to
  /// `safeCutoff = currentHeight - reorgDepth` so we never have to rewrite
  /// already-persisted entries on a reorg; transfers above `safeCutoff` simply
  /// aren't cached and are re-queried next time.
  Future<({Map<String, List<WormholeTransfer>> byAddress, int safeCutoff})> getTransfersToMany(
    List<String> addresses, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    final sw = Stopwatch()..start();
    _log('getTransfersToMany START (${addresses.length} addresses)');

    final chainHeight = await _getChainHeight();
    final safeCutoff = (chainHeight - _reorgDepth).clamp(0, chainHeight);
    _log('chainHeight=$chainHeight safeCutoff=$safeCutoff');

    final caches = <String, _TransferCache>{};
    var cachedCount = 0;
    for (final address in addresses) {
      final cache = await _loadTransferCache(_addressHashOf(address));
      caches[address] = cache;
      cachedCount += cache.transfers.length;
    }
    _log('Caches: $cachedCount transfers across ${addresses.length} addresses');
    if (cachedCount > 0) onProgress?.call(1, cachedCount);

    _throwIfCancelled(isCancelled);

    // Cache invariant: every entry has blockHeight <= cachedUpToBlock, so a
    // GraphQL filter of `height_gt: cachedUpToBlock` correctly fetches only
    // what we don't already have.
    final newByAddress = <String, List<WormholeTransfer>>{for (final a in addresses) a: []};
    var fetchedCount = 0;
    for (final address in addresses) {
      final upTo = caches[address]!.cachedUpToBlock;
      if (upTo >= chainHeight) continue;
      _throwIfCancelled(isCancelled);
      _log('Querying next address after block $upTo');
      final addressBase = fetchedCount;
      final fetched = await fetchAllTransfers(
        toAddress: address,
        afterBlock: upTo,
        onFetched: (n) => onProgress?.call(1, cachedCount + addressBase + n),
        isCancelled: isCancelled,
      );
      fetchedCount += fetched.length;
      for (final t in fetched) {
        if (t.toId != address) {
          throw StateError('Indexer returned transfer to unrequested address ${t.toId}');
        }
        newByAddress[address]!.add(t);
      }
    }

    final byAddress = <String, List<WormholeTransfer>>{};
    for (final address in addresses) {
      final all = [...caches[address]!.transfers, ...newByAddress[address]!];
      byAddress[address] = all;
      // Cache only the reorg-safe slice; the caller still sees recent
      // (above-cutoff) transfers so balances / claims include them.
      final safe = all.where((t) => t.blockHeight <= safeCutoff).toList();
      await _saveTransferCache(_addressHashOf(address), _TransferCache(cachedUpToBlock: safeCutoff, transfers: safe));
    }
    onProgress?.call(1, cachedCount + fetchedCount);

    _log('getTransfersToMany DONE: ${cachedCount + fetchedCount} transfers (${sw.elapsedMilliseconds}ms)');
    return (byAddress: byAddress, safeCutoff: safeCutoff);
  }

  Future<({List<WormholeTransfer> transfers, int safeCutoff})> getTransfersTo(
    String wormholeAddress, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    final fetched = await getTransfersToMany([wormholeAddress], onProgress: onProgress, isCancelled: isCancelled);
    return (transfers: fetched.byAddress[wormholeAddress]!, safeCutoff: fetched.safeCutoff);
  }

  /// Scans every transfer ever received on [addresses] and looks up which of
  /// them are spent. Each transfer is attributed to its owning address (whose
  /// secret is needed to spend it); each spend carries the consuming extrinsic
  /// and its exits so callers can reconstruct the account's history.
  Future<WormholeUtxoResult> getUnspentUtxos({
    required List<WormholeAddressInfo> addresses,
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    _log('getUnspentUtxos(${addresses.length} addresses)');
    final fetched = await getTransfersToMany(
      addresses.map((a) => a.address).toList(),
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    final safeCutoff = fetched.safeCutoff;
    final totalTransfers = fetched.byAddress.values.fold<int>(0, (sum, l) => sum + l.length);
    if (totalTransfers == 0) {
      _log('getUnspentUtxos: no transfers found');
      return const WormholeUtxoResult(received: [], spends: {});
    }

    final hdWalletService = HdWalletService();
    final uncheckedPairs = <(String, String)>[];
    final received = <WormholeUtxo>[];
    final ownerHashByNullifier = <String, String>{};
    final cachedSpentByOwner = <String, Map<String, WormholeSpend>>{};
    final spends = <String, WormholeSpend>{};
    int processed = 0;
    int skipped = 0;

    for (final owner in addresses) {
      final ownerHash = _addressHashOf(owner.address);
      final cachedSpent = await loadSpentNullifiers(ownerHash);
      cachedSpentByOwner[ownerHash] = cachedSpent;
      spends.addAll(cachedSpent);

      for (final transfer in fetched.byAddress[owner.address]!) {
        _throwIfCancelled(isCancelled);
        final nullifierHex = hdWalletService.computeNullifier(
          secretHex: owner.secretHex,
          transferCount: transfer.transferCount,
        );
        // The secret is used only for the nullifier above — the returned UTXO
        // carries a blanked owner so no secret is retained in app state (M11).
        final redactedOwner = WormholeAddressInfo(
          index: owner.index,
          isChange: owner.isChange,
          address: owner.address,
          secretHex: '',
        );
        received.add(WormholeUtxo(transfer: transfer, owner: redactedOwner, nullifierHex: nullifierHex));
        ownerHashByNullifier[nullifierHex] = ownerHash;
        if (cachedSpent.containsKey(nullifierHex)) {
          skipped++;
        } else {
          final nullifierBytes = hex.decode(nullifierHex.replaceFirst('0x', ''));
          final nullifierHash = _addressHash(Uint8List.fromList(nullifierBytes));
          uncheckedPairs.add((nullifierHex, nullifierHash));
        }
        processed++;
        onProgress?.call(2, processed, total: totalTransfers);
      }
    }
    _log('Computed nullifiers: $skipped cached-spent, ${uncheckedPairs.length} to check');

    if (uncheckedPairs.isNotEmpty) {
      final newSpent = await checkNullifiersSpent(uncheckedPairs, onProgress: onProgress, isCancelled: isCancelled);
      // In-memory: every spent nullifier we've seen, including ones in
      // unfinalized blocks — must not be re-claimed in this call.
      spends.addAll(newSpent);
      // Persist: only entries from finalized blocks (height <= safeCutoff),
      // each in its owning address's cache. Unfinalized ones get re-queried
      // next call so a reorg can correct them.
      var unfinalizedCount = 0;
      final toPersistByOwner = <String, Map<String, WormholeSpend>>{
        for (final e in cachedSpentByOwner.entries) e.key: {...e.value},
      };
      for (final entry in newSpent.entries) {
        if (entry.value.blockHeight > safeCutoff) {
          unfinalizedCount++;
          continue;
        }
        toPersistByOwner[ownerHashByNullifier[entry.key]!]![entry.key] = entry.value;
      }
      for (final entry in toPersistByOwner.entries) {
        if (entry.value.length != cachedSpentByOwner[entry.key]!.length) {
          await saveSpentNullifiers(entry.key, entry.value);
        }
      }
      _log('Nullifier persistence: skipped $unfinalizedCount above cutoff $safeCutoff');
    }

    final result = WormholeUtxoResult(received: received, spends: spends);
    _log('getUnspentUtxos: ${result.utxos.length} unspent out of $totalTransfers total');
    return result;
  }

  Future<List<WormholeTransfer>> getUnspentTransfers({
    required String wormholeAddress,
    required String secretHex,
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    final result = await getUnspentUtxos(
      addresses: [WormholeAddressInfo(index: 0, address: wormholeAddress, secretHex: secretHex)],
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return result.utxos.map((u) => u.transfer).toList();
  }

  Future<BigInt> getUnspentBalance({
    required String wormholeAddress,
    required String secretHex,
    IsCancelledCallback? isCancelled,
  }) async {
    _log('getUnspentBalance($wormholeAddress)');
    final unspent = await getUnspentTransfers(
      wormholeAddress: wormholeAddress,
      secretHex: secretHex,
      isCancelled: isCancelled,
    );
    final balance = unspent.fold<BigInt>(BigInt.zero, (sum, t) => sum + t.amount);
    _log('getUnspentBalance: $balance token units (${unspent.length} unspent transfers)');
    return balance;
  }
}

class _TransferCache {
  final int cachedUpToBlock;
  final List<WormholeTransfer> transfers;

  _TransferCache({required this.cachedUpToBlock, required this.transfers});

  factory _TransferCache.empty() => _TransferCache(cachedUpToBlock: 0, transfers: []);

  factory _TransferCache.fromJson(Map<String, dynamic> json) {
    final transfers = (json['transfers'] as List<dynamic>)
        .map((t) => WormholeTransfer.fromJson(t as Map<String, dynamic>))
        .toList();
    return _TransferCache(cachedUpToBlock: json['cachedUpToBlock'] as int, transfers: transfers);
  }

  Map<String, dynamic> toJson() => {
    'cachedUpToBlock': cachedUpToBlock,
    'transfers': transfers.map((t) => t.toJson()).toList(),
  };
}
