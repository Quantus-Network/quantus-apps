import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole_ffi;
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';

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
  static const int _transferPageSize = 300;
  static const int _nullifierBatchSize = 300;
  static const int _reorgDepth = 180;

  final GraphQlEndpointService _graphQlEndpoint = GraphQlEndpointService();
  final RpcEndpointService _rpcEndpoint = RpcEndpointService();

  static void _log(String msg) => print('[WormholeUtxo] $msg');

  static String _addressHash(Uint8List raw32) => wormhole_ffi.computeAddressHashHex(rawAddress: raw32);

  static void _throwIfCancelled(IsCancelledCallback? isCancelled) {
    if (isCancelled?.call() == true) throw const WormholeOperationCancelled();
  }

  // --- Cache ---

  static String _cachePrefix(String addressHash) => addressHash.substring(0, 16);

  static Future<File> _transferCacheFile(String addressHash) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/wormhole_cache_${_cachePrefix(addressHash)}.json');
  }

  /// Bumped to v2 to drop any pre-finalization-filter caches that may contain
  /// nullifiers from reorged-out blocks. Old `wormhole_nullifiers_<prefix>.json`
  /// files are best-effort deleted on first read.
  static Future<File> _nullifierCacheFile(String addressHash) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/wormhole_nullifiers_v2_${_cachePrefix(addressHash)}.json');
  }

  static Future<void> _deleteLegacyNullifierCache(String addressHash) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final legacy = File('${dir.path}/wormhole_nullifiers_${_cachePrefix(addressHash)}.json');
      if (await legacy.exists()) {
        await legacy.delete();
        _log('Deleted legacy nullifier cache: ${legacy.path}');
      }
    } catch (e) {
      _log('Legacy nullifier cache delete failed (non-fatal): $e');
    }
  }

  static Future<_TransferCache> _loadTransferCache(String addressHash) async {
    try {
      final file = await _transferCacheFile(addressHash);
      if (!await file.exists()) return _TransferCache.empty();
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _TransferCache.fromJson(json);
    } catch (e) {
      _log('Transfer cache load failed: $e');
      return _TransferCache.empty();
    }
  }

  static Future<void> _saveTransferCache(String addressHash, _TransferCache cache) async {
    try {
      final file = await _transferCacheFile(addressHash);
      await file.writeAsString(jsonEncode(cache.toJson()));
      _log('Transfer cache saved: ${cache.transfers.length} transfers up to block ${cache.cachedUpToBlock}');
    } catch (e) {
      _log('Transfer cache save failed: $e');
    }
  }

  static Future<Set<String>> _loadSpentNullifiers(String addressHash) async {
    await _deleteLegacyNullifierCache(addressHash);
    try {
      final file = await _nullifierCacheFile(addressHash);
      if (!await file.exists()) return {};
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (e) {
      _log('Nullifier cache load failed: $e');
      return {};
    }
  }

  static Future<void> _saveSpentNullifiers(String addressHash, Set<String> spent) async {
    try {
      final file = await _nullifierCacheFile(addressHash);
      await file.writeAsString(jsonEncode(spent.toList()));
      _log('Nullifier cache saved: ${spent.length} spent nullifiers');
    } catch (e) {
      _log('Nullifier cache save failed: $e');
    }
  }

  // --- Block height ---

  /// Current chain head (best block) height. Throws if RPC fails — callers must
  /// not advance the cache from a fabricated value.
  Future<int> _getChainHeight() async {
    final body = jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'chain_getHeader', 'params': []});
    final response = await _rpcEndpoint.post(body: body);
    if (response.statusCode != 200) {
      throw Exception('chain_getHeader HTTP ${response.statusCode}: ${response.body}');
    }
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed['error'] != null) {
      throw Exception('chain_getHeader RPC error: ${parsed['error']}');
    }
    final numberHex = parsed['result']?['number'] as String?;
    if (numberHex == null) {
      throw Exception('chain_getHeader returned no number: ${response.body}');
    }
    final height = int.parse(numberHex.replaceFirst('0x', ''), radix: 16);
    _log('Chain height from RPC: $height');
    return height;
  }

  // --- GraphQL queries ---

  Future<List<WormholeTransfer>> _queryTransfers({
    required String toAddress,
    int limit = _transferPageSize,
    int offset = 0,
    int? afterBlock,
  }) async {
    const query = r'''
query TransfersToAddress($to: String!, $limit: Int!, $offset: Int!, $afterBlock: Int) {
  transfers: transfer(
    where: { to: { id: {_eq: $to } }, block: { height: {_gt: $afterBlock } } }
    order_by: {block_height: asc}
    limit: $limit
    offset: $offset
  ) {
    id
    block { height }
    from { id }
    to { id }
    amount
    toHash: to_hash
    leafIndex: leaf_index
    transferCount: transfer_count
  }
}''';

    final variables = <String, dynamic>{
      'to': toAddress,
      'limit': limit,
      'offset': offset,
      'afterBlock': afterBlock ?? 0,
    };

    final body = jsonEncode({'query': query, 'variables': variables});

    _log(
      '=== TRANSFERS QUERY ===\n'
      'to=$toAddress limit=$limit offset=$offset afterBlock=${afterBlock ?? 0}',
    );

    final sw = Stopwatch()..start();
    final response = await _graphQlEndpoint.post(body: body);
    final elapsed = sw.elapsedMilliseconds;
    _log('transfers query: status=${response.statusCode} offset=$offset elapsed=${elapsed}ms');

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

    return transfers.map((t) {
      final m = t as Map<String, dynamic>;
      return WormholeTransfer(
        id: m['id'] as String,
        blockHeight: (m['block'] as Map<String, dynamic>)['height'] as int,
        fromId: (m['from'] as Map<String, dynamic>)['id'] as String,
        toId: (m['to'] as Map<String, dynamic>)['id'] as String,
        amount: BigInt.parse(m['amount'] as String),
        toHash: m['toHash'] as String? ?? '',
        leafIndex: BigInt.parse(m['leafIndex'] as String),
        transferCount: BigInt.parse(m['transferCount'] as String),
      );
    }).toList();
  }

  Future<List<WormholeTransfer>> _fetchAllTransfers({
    required String toAddress,
    int? afterBlock,
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    final totalSw = Stopwatch()..start();
    final all = <WormholeTransfer>[];
    int offset = 0;
    int pageNum = 0;
    while (true) {
      _throwIfCancelled(isCancelled);
      pageNum++;
      final page = await _queryTransfers(
        toAddress: toAddress,
        limit: _transferPageSize,
        offset: offset,
        afterBlock: afterBlock,
      );
      all.addAll(page);
      onProgress?.call(1, all.length);
      _log(
        'Page $pageNum: got ${page.length} transfers, total so far: ${all.length} (${totalSw.elapsedMilliseconds}ms elapsed)',
      );
      if (page.isEmpty || page.length < _transferPageSize) break;
      offset += _transferPageSize;
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
  /// persist (see `getUnspentTransfers`).
  Future<Map<String, int>> _checkNullifiersSpent(
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

  /// Fetches every wormhole transfer ever sent to [wormholeAddress] and
  /// returns them along with the reorg-safe block cutoff used for caching.
  ///
  /// `transfers` includes everything up to the current chain head. The on-disk
  /// cache only advances to `safeCutoff = currentHeight - reorgDepth` so we
  /// never have to rewrite already-persisted entries on a reorg; callers above
  /// `safeCutoff` simply aren't cached and are re-queried next time.
  Future<({List<WormholeTransfer> transfers, int safeCutoff})> getTransfersTo(
    String wormholeAddress, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    final sw = Stopwatch()..start();
    _log('getTransfersTo START ($wormholeAddress)');

    final raw = Uint8List.fromList(getAccountId32(wormholeAddress));
    final fullHash = _addressHash(raw);

    final chainHeight = await _getChainHeight();
    final safeCutoff = (chainHeight - _reorgDepth).clamp(0, chainHeight);
    _log('chainHeight=$chainHeight safeCutoff=$safeCutoff');

    final cache = await _loadTransferCache(fullHash);
    _log('Cache: ${cache.transfers.length} transfers up to block ${cache.cachedUpToBlock}');
    if (cache.transfers.isNotEmpty) onProgress?.call(1, cache.transfers.length);

    _throwIfCancelled(isCancelled);

    // Cache invariant: every entry has blockHeight <= cachedUpToBlock, so a
    // GraphQL filter of `height_gt: cachedUpToBlock` correctly fetches only
    // what we don't already have. Previous code added +1 here, which combined
    // with `height_gt` skipped block `cachedUpToBlock + 1` entirely.
    final List<WormholeTransfer> newTransfers;
    if (cache.cachedUpToBlock >= chainHeight) {
      _log('Cache is current, no new blocks to query');
      newTransfers = const [];
    } else {
      _log('Querying transfers after block ${cache.cachedUpToBlock}');
      newTransfers = await _fetchAllTransfers(
        toAddress: wormholeAddress,
        afterBlock: cache.cachedUpToBlock,
        onProgress: onProgress != null
            ? (phase, completed, {int? total}) => onProgress(phase, cache.transfers.length + completed, total: total)
            : null,
        isCancelled: isCancelled,
      );
      _log('New transfers: ${newTransfers.length}');
    }

    final allTransfers = [...cache.transfers, ...newTransfers];
    onProgress?.call(1, allTransfers.length);
    _log('Total transfers: ${allTransfers.length} (${cache.transfers.length} cached + ${newTransfers.length} new)');

    // Cache only the reorg-safe slice; the caller still sees recent (above-cutoff)
    // transfers so balances / claims include them.
    final safeTransfers = allTransfers.where((t) => t.blockHeight <= safeCutoff).toList();
    await _saveTransferCache(fullHash, _TransferCache(cachedUpToBlock: safeCutoff, transfers: safeTransfers));

    _log('getTransfersTo DONE: ${allTransfers.length} transfers (${sw.elapsedMilliseconds}ms)');
    return (transfers: allTransfers, safeCutoff: safeCutoff);
  }

  Future<List<WormholeTransfer>> getUnspentTransfers({
    required String wormholeAddress,
    required String secretHex,
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    _log('getUnspentTransfers($wormholeAddress)');
    final fetched = await getTransfersTo(wormholeAddress, onProgress: onProgress, isCancelled: isCancelled);
    final transfers = fetched.transfers;
    final safeCutoff = fetched.safeCutoff;
    if (transfers.isEmpty) {
      _log('getUnspentTransfers: no transfers found');
      return [];
    }

    final raw = Uint8List.fromList(getAccountId32(wormholeAddress));
    final fullHash = _addressHash(raw);
    final cachedSpent = await _loadSpentNullifiers(fullHash);
    _log('Nullifier cache: ${cachedSpent.length} known spent');

    final hdWalletService = HdWalletService();
    final uncheckedPairs = <(String, String)>[];
    final nullifierToTransfer = <String, WormholeTransfer>{};
    final allSpent = <String>{...cachedSpent};
    int skipped = 0;

    for (int i = 0; i < transfers.length; i++) {
      _throwIfCancelled(isCancelled);
      final transfer = transfers[i];
      final nullifierHex = hdWalletService.computeNullifier(
        secretHex: secretHex,
        transferCount: transfer.transferCount,
      );
      nullifierToTransfer[nullifierHex] = transfer;
      if (cachedSpent.contains(nullifierHex)) {
        skipped++;
      } else {
        final nullifierBytes = hex.decode(nullifierHex.replaceFirst('0x', ''));
        final nullifierHash = _addressHash(Uint8List.fromList(nullifierBytes));
        uncheckedPairs.add((nullifierHex, nullifierHash));
      }
      onProgress?.call(2, i + 1, total: transfers.length);
    }
    _log('Computed nullifiers: $skipped cached-spent, ${uncheckedPairs.length} to check');

    if (uncheckedPairs.isNotEmpty) {
      final newSpent = await _checkNullifiersSpent(uncheckedPairs, onProgress: onProgress, isCancelled: isCancelled);
      // In-memory: every spent nullifier we've seen, including ones in
      // unfinalized blocks — must not be re-claimed in this call.
      allSpent.addAll(newSpent.keys);
      // Persist: only entries from finalized blocks (height <= safeCutoff).
      // Unfinalized ones get re-queried next call so a reorg can correct them.
      final newSafe = newSpent.entries.where((e) => e.value <= safeCutoff).map((e) => e.key);
      final unfinalizedCount = newSpent.length - newSafe.length;
      final toPersist = <String>{...cachedSpent, ...newSafe};
      await _saveSpentNullifiers(fullHash, toPersist);
      _log(
        'Nullifier persistence: kept ${toPersist.length} finalized '
        '(skipped $unfinalizedCount above cutoff $safeCutoff)',
      );
    }

    final unspent = nullifierToTransfer.entries.where((e) => !allSpent.contains(e.key)).map((e) => e.value).toList();
    _log('getUnspentTransfers: ${unspent.length} unspent out of ${transfers.length} total');
    return unspent;
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
    _log('getUnspentBalance: $balance planck (${unspent.length} unspent transfers)');
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
