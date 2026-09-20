import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart' show protected, visibleForTesting;
import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole_ffi;
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';
import 'package:quantus_sdk/src/utils/app_support_files.dart';
import 'package:quantus_sdk/src/utils/print.dart';

class WormholeTransfer {
  final String id;
  final int blockHeight;
  final String fromId;
  final String toId;
  final BigInt amount;
  final String toHash;
  final BigInt leafIndex;
  final BigInt transferCount;

  const WormholeTransfer({
    required this.id,
    required this.blockHeight,
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.toHash,
    required this.leafIndex,
    required this.transferCount,
  });

  factory WormholeTransfer.fromJson(Map<String, dynamic> json) {
    return WormholeTransfer(
      id: json['id'] as String,
      blockHeight: json['blockHeight'] as int,
      fromId: json['fromId'] as String? ?? '',
      toId: json['toId'] as String? ?? '',
      amount: BigInt.parse(json['amount'] as String),
      toHash: json['toHash'] as String? ?? '',
      leafIndex: BigInt.parse(json['leafIndex'] as String),
      transferCount: BigInt.parse(json['transferCount'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'blockHeight': blockHeight,
    'fromId': fromId,
    'toId': toId,
    'amount': amount.toString(),
    'toHash': toHash,
    'leafIndex': leafIndex.toString(),
    'transferCount': transferCount.toString(),
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
/// with [isChange] selecting the change branch of the derivation path). Carries
/// no secret: UTXOs are kept in long-lived app state, and spenders re-derive
/// from [index]/[isChange] when needed (M11).
class WormholeAddressInfo {
  final int index;
  final bool isChange;
  final String address;

  const WormholeAddressInfo({required this.index, this.isChange = false, required this.address});
}

/// Nullifier of the [transferCount]-th transfer to [owner]. Needs the owner's
/// secret, so the caller decides when the seed is read.
typedef NullifierResolver = Future<String> Function(WormholeAddressInfo owner, BigInt transferCount);

/// An unspent wormhole transfer together with the address that owns it.
class WormholeUtxo {
  final WormholeTransfer transfer;
  final WormholeAddressInfo owner;
  final String nullifierHex;

  const WormholeUtxo({required this.transfer, required this.owner, required this.nullifierHex});

  BigInt get amount => transfer.amount;
}

class WormholeUtxoResult {
  final List<WormholeUtxo> utxos;
  final BigInt totalReceivedToken;

  /// Slice of [totalReceivedToken] received on change-branch addresses, so
  /// callers can report externally received funds separately from change.
  final BigInt changeReceivedToken;
  final BigInt totalSpentToken;

  const WormholeUtxoResult({
    required this.utxos,
    required this.totalReceivedToken,
    required this.changeReceivedToken,
    required this.totalSpentToken,
  });
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
  /// instead of being read against mainnet.
  @visibleForTesting
  static const int cacheVersion = 3;
  static const int _nullifierBatchSize = 300;
  static const int _reorgDepth = 180;

  static const String _transferSelection = r'''
    id
    blockHeight: block_height
    fromId: from_id
    toId: to_id
    amount
    toHash: to_hash
    leafIndex: leaf_index
    transferCount: transfer_count''';

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

  Future<File> _cacheFile(String kind, String addressHash) async =>
      appSupportFile(_cacheName(kind, await networkId(), _cachePrefix(addressHash)));

  /// Deletes every cache file of [addressHash] from an earlier generation.
  /// Current-generation files of other networks stay, so switching chains
  /// back and forth does not rescan.
  @visibleForTesting
  static Future<void> deleteStaleCaches(String addressHash) async {
    try {
      final prefix = _cachePrefix(addressHash);
      final deleted = await deleteAppSupportFiles(
        (name) => _isCacheFileFor(name, prefix) && !_currentGeneration.hasMatch(name),
      );
      if (deleted > 0) _log('Deleted $deleted stale cache file(s) for $prefix');
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
  Future<Set<String>> loadSpentNullifiers(String addressHash) async {
    await deleteStaleCaches(addressHash);
    try {
      final file = await _cacheFile('nullifiers', addressHash);
      if (!await file.exists()) return {};
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (e) {
      _log('Nullifier cache load failed: $e');
      return {};
    }
  }

  @visibleForTesting
  Future<void> saveSpentNullifiers(String addressHash, Set<String> spent) async {
    try {
      final file = await _cacheFile('nullifiers', addressHash);
      await file.writeAsString(jsonEncode(spent.toList()));
      _log('Nullifier cache saved: ${spent.length} spent nullifiers');
    } catch (e) {
      _log('Nullifier cache save failed: $e');
    }
  }

  /// Deletes transfer / nullifier caches only for the given [addresses].
  static Future<void> clearCachesForAddresses(List<String> addresses) async {
    try {
      final prefixes = addresses.map((a) => _cachePrefix(_addressHashOf(a))).toSet();
      final deleted = await deleteAppSupportFiles((name) => prefixes.any((p) => _isCacheFileFor(name, p)));
      _log('clearCachesForAddresses: deleted $deleted file(s) for ${addresses.length} addresses');
    } catch (e) {
      _log('clearCachesForAddresses failed (non-fatal): $e');
    }
  }

  /// Deletes every on-disk wormhole transfer / nullifier cache. Call on logout
  /// so a new wallet never reuses another wallet's UTXO discovery state.
  static Future<void> clearAllCaches() async {
    try {
      final deleted = await deleteAppSupportFiles(
        (name) => name.startsWith('wormhole_cache_') || name.startsWith('wormhole_nullifiers'),
      );
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

    final body = jsonEncode({'query': document, 'variables': variables});

    _log(
      '=== TRANSFERS QUERY ===\n'
      'limit=$limit afterBlock=$afterBlock cursor=$after',
    );

    final sw = Stopwatch()..start();
    final response = await _graphQlEndpoint.post(body: body);
    final elapsed = sw.elapsedMilliseconds;
    _log('transfers query: status=${response.statusCode} cursor=$after elapsed=${elapsed}ms');

    if (response.statusCode != 200) {
      _log('transfers query FAILED: ${response.body}');
      throw Exception('Subsquid request failed ${response.statusCode}: ${response.body}');
    }

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['errors'] != null) {
      final msgs = (parsed['errors'] as List).map((e) => (e as Map)['message']).join('; ');
      _log('transfers query GraphQL errors: $msgs');
      throw Exception('GraphQL errors: $msgs');
    }

    final transfers = parsed['data']?['transfers'] as List<dynamic>?;
    final count = transfers?.length ?? 0;
    _log('transfers query: received $count transfers (${elapsed}ms)');
    if (transfers == null || transfers.isEmpty) return [];

    return transfers.map((t) => WormholeTransfer.fromJson(t as Map<String, dynamic>)).toList();
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
  /// map from nullifier hash to the block height the nullifier was recorded in,
  /// so callers can decide whether the entry is reorg-safe to persist.
  Future<Map<String, int>> _querySpentNullifierHashes(List<String> nullifierHashes) async {
    const query = r'''
query SpentNullifiers($hashes: [String!]!) {
  wormholeNullifiers: wormhole_nullifier(where: { nullifier_hash: {_in: $hashes } }, limit: 1000) {
    nullifierHash: nullifier_hash
    block { height }
  }
}''';

    final body = jsonEncode({
      'query': query,
      'variables': {'hashes': nullifierHashes},
    });

    _log('nullifiers query: ${nullifierHashes.length} hashes');
    final sw = Stopwatch()..start();
    final response = await _graphQlEndpoint.post(body: body);
    final elapsed = sw.elapsedMilliseconds;
    _log('nullifiers query: status=${response.statusCode} elapsed=${elapsed}ms');

    if (response.statusCode != 200) {
      _log('nullifiers query FAILED: ${response.body}');
      throw Exception('Subsquid nullifiers request failed ${response.statusCode}: ${response.body}');
    }

    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['errors'] != null) {
      final msgs = (parsed['errors'] as List).map((e) => (e as Map)['message']).join('; ');
      _log('nullifiers query GraphQL errors: $msgs');
      throw Exception('GraphQL errors: $msgs');
    }

    final results = parsed['data']?['wormholeNullifiers'] as List<dynamic>?;
    final found = <String, int>{};
    for (final r in results ?? const []) {
      final m = r as Map<String, dynamic>;
      final hash = m['nullifierHash'] as String;
      final height = (m['block'] as Map<String, dynamic>)['height'] as int;
      found[hash] = height;
    }
    _log('nullifiers query: ${found.length} spent out of ${nullifierHashes.length} queried (${elapsed}ms)');
    return found;
  }

  /// Returns a map from nullifier hex to the block height where it was spent.
  /// Callers are responsible for deciding which entries are reorg-safe to
  /// persist (see `getUnspentUtxos`).
  @visibleForTesting
  Future<Map<String, int>> checkNullifiersSpent(
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
    final spent = <String, int>{};
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

  /// Returns the unspent transfers across all [addresses], each attributed to
  /// its owning address (whose secret is needed to spend it), along with total
  /// received and spent amounts across all addresses.
  Future<WormholeUtxoResult> getUnspentUtxos({
    required List<WormholeAddressInfo> addresses,
    required NullifierResolver nullifierFor,
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
      return WormholeUtxoResult(
        utxos: const [],
        totalReceivedToken: BigInt.zero,
        changeReceivedToken: BigInt.zero,
        totalSpentToken: BigInt.zero,
      );
    }

    BigInt totalReceivedToken = BigInt.zero;
    BigInt changeReceivedToken = BigInt.zero;
    for (final owner in addresses) {
      for (final t in fetched.byAddress[owner.address]!) {
        totalReceivedToken += t.amount;
        if (owner.isChange) changeReceivedToken += t.amount;
      }
    }

    final uncheckedPairs = <(String, String)>[];
    final nullifierToUtxo = <String, WormholeUtxo>{};
    final cachedSpentByOwner = <String, Set<String>>{};
    final allSpent = <String>{};
    int processed = 0;
    int skipped = 0;

    for (final owner in addresses) {
      final ownerHash = _addressHashOf(owner.address);
      final cachedSpent = await loadSpentNullifiers(ownerHash);
      cachedSpentByOwner[ownerHash] = cachedSpent;
      allSpent.addAll(cachedSpent);

      for (final transfer in fetched.byAddress[owner.address]!) {
        _throwIfCancelled(isCancelled);
        final nullifierHex = await nullifierFor(owner, transfer.transferCount);
        nullifierToUtxo[nullifierHex] = WormholeUtxo(transfer: transfer, owner: owner, nullifierHex: nullifierHex);
        if (cachedSpent.contains(nullifierHex)) {
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
      allSpent.addAll(newSpent.keys);
      // Persist: only entries from finalized blocks (height <= safeCutoff),
      // each in its owning address's cache. Unfinalized ones get re-queried
      // next call so a reorg can correct them.
      var unfinalizedCount = 0;
      final toPersistByOwner = <String, Set<String>>{
        for (final e in cachedSpentByOwner.entries) e.key: {...e.value},
      };
      for (final entry in newSpent.entries) {
        if (entry.value > safeCutoff) {
          unfinalizedCount++;
          continue;
        }
        final ownerHash = _addressHashOf(nullifierToUtxo[entry.key]!.owner.address);
        toPersistByOwner[ownerHash]!.add(entry.key);
      }
      for (final entry in toPersistByOwner.entries) {
        if (entry.value.length != cachedSpentByOwner[entry.key]!.length) {
          await saveSpentNullifiers(entry.key, entry.value);
        }
      }
      _log('Nullifier persistence: skipped $unfinalizedCount above cutoff $safeCutoff');
    }

    final unspent = nullifierToUtxo.entries.where((e) => !allSpent.contains(e.key)).map((e) => e.value).toList();
    final totalSpentToken = nullifierToUtxo.entries
        .where((e) => allSpent.contains(e.key))
        .fold(BigInt.zero, (sum, e) => sum + e.value.amount);
    _log('getUnspentUtxos: ${unspent.length} unspent out of $totalTransfers total');
    return WormholeUtxoResult(
      utxos: unspent,
      totalReceivedToken: totalReceivedToken,
      changeReceivedToken: changeReceivedToken,
      totalSpentToken: totalSpentToken,
    );
  }

  Future<List<WormholeTransfer>> getUnspentTransfers({
    required String wormholeAddress,
    required String secretHex,
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    final result = await getUnspentUtxos(
      addresses: [WormholeAddressInfo(index: 0, address: wormholeAddress)],
      nullifierFor: (_, transferCount) async =>
          HdWalletService().computeNullifier(secretHex: secretHex, transferCount: transferCount),
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
