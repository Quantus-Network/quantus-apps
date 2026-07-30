import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quantus_sdk/src/services/account_discovery_service.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart' show getAccountId32;
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_send_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

typedef MnemonicGetter = Future<String?> Function();

/// Snapshot of an encrypted account: spendable UTXOs across all discovered
/// wormhole addresses, plus change that has been submitted but not yet indexed.
class EncryptedAccountState {
  final List<WormholeUtxo> utxos;
  final BigInt pendingChangeRaw;
  final BigInt totalReceivedRaw;

  /// Slice of [totalReceivedRaw] that arrived on change-branch addresses.
  final BigInt changeReceivedRaw;
  final BigInt totalSpentRaw;

  /// Next unused external index — shown as the receive address.
  final int nextIndex;

  /// Next unused change-branch index — allocated as the change address of the
  /// next send.
  final int nextChangeIndex;

  const EncryptedAccountState({
    required this.utxos,
    required this.pendingChangeRaw,
    required this.totalReceivedRaw,
    required this.changeReceivedRaw,
    required this.totalSpentRaw,
    required this.nextIndex,
    required this.nextChangeIndex,
  });

  BigInt get balance => utxos.fold(BigInt.zero, (sum, u) => sum + u.amount) + pendingChangeRaw;

  /// Externally received funds only: change outputs return to the change
  /// branch and are excluded, so the indexed (non-pending) balance equals
  /// `incomingRaw + changeReceivedRaw - totalSpentRaw`.
  BigInt get incomingRaw => totalReceivedRaw - changeReceivedRaw;

  /// Max amount sendable right now (post volume fee, excluding pending change).
  BigInt get maxSendable => wormholeMaxSendable(utxos);
}

/// An encrypted account: two HD sequences of wormhole addresses treated as a
/// single pool of funds — an external branch (`m/44'/189189189'/0'/0'/n'`)
/// whose next unused index is shown for receiving, and a change branch
/// (`m/44'/189189189'/0'/1'/n'`) whose next unused index is consumed as the
/// fresh change address of each send. Both branches are gap-limit scanned
/// (same algorithm as transparent accounts) so all funds are rediscovered
/// from the mnemonic alone, and keeping change off the external branch lets
/// externally received funds be reported separately from returning change.
/// Spent inputs are excluded via on-chain nullifiers; in-flight sends are
/// bridged by locally persisted pending-spend records until the indexer
/// catches up.
///
/// Secret hygiene (M11): wormhole key pairs are never cached — every use
/// re-derives from the mnemonic and the result is dropped as soon as the
/// operation completes. Secrets held in [Uint8List] form (spend proofs) are
/// zeroized immediately after use; the FRB API hands secrets back as
/// immutable Dart Strings, which cannot be overwritten in place, so their
/// lifetime is kept function-local (no fields, no caches) — that is the best
/// Dart allows.
class EncryptedAccountService {
  static const Duration _pendingSpendExpiry = Duration(hours: 1);

  final int walletIndex;
  final MnemonicGetter _getMnemonic;
  final HdWalletService _hdWalletService;
  final WormholeUtxoService _utxoService;
  final AccountDiscoveryService _discoveryService;
  final WormholeSendService _sendService;

  Future<void> _stateLock = Future.value();

  /// Change indices claimed by in-flight sends, so two overlapping sends can
  /// never allocate the same change address. Released when the send finishes
  /// (by then a change-bearing batch has bumped the persisted nextIndex).
  final Set<int> _reservedChangeIndices = {};

  /// Every not-yet-disposed instance, so logout can quiesce all in-flight
  /// encrypted work ([disposeAll]) before session state is wiped.
  static final Set<EncryptedAccountService> _live = {};

  bool _disposed = false;

  EncryptedAccountService({
    required this.walletIndex,
    required MnemonicGetter getMnemonic,
    HdWalletService? hdWalletService,
    WormholeUtxoService? utxoService,
    AccountDiscoveryService? discoveryService,
    WormholeSendService? sendService,
  }) : _getMnemonic = getMnemonic,
       _hdWalletService = hdWalletService ?? HdWalletService(),
       _utxoService = utxoService ?? WormholeUtxoService(),
       _discoveryService = discoveryService ?? AccountDiscoveryService(hdWalletService ?? HdWalletService()),
       _sendService = sendService ?? WormholeSendService() {
    _live.add(this);
  }

  static void _log(String msg) => quantusPrint('[EncryptedAccount] $msg');

  void _checkNotDisposed() {
    if (_disposed) throw StateError('EncryptedAccountService for wallet $walletIndex was disposed (logout)');
  }

  /// Quiesces this instance: refuses new work, cancels and awaits any
  /// in-flight send, and drains queued state mutations. After this returns,
  /// no code path of this instance can touch the persisted state file again
  /// (the disposed gate inside [_mutateState] makes late callbacks fail
  /// instead of resurrecting cleared state).
  Future<void> dispose() async {
    _live.remove(this);
    if (_disposed) {
      await _stateLock;
      return;
    }
    _disposed = true;
    try {
      await _sendService.cancel();
    } catch (e) {
      _log('dispose: cancelling in-flight send failed (non-fatal): $e');
    }
    await _stateLock;
  }

  /// Cancels and awaits every live encrypted-account operation. Must be
  /// called on logout *before* mnemonics, settings or persisted state are
  /// cleared, so no delayed load/send can outlive the session.
  static Future<void> disposeAll() async {
    final live = List.of(_live);
    if (live.isEmpty) return;
    _log('disposeAll: quiescing ${live.length} live instance(s)');
    await Future.wait(live.map((s) => s.dispose()));
  }

  Future<String> _mnemonic() async {
    final mnemonic = await _getMnemonic();
    if (mnemonic == null) throw StateError('No mnemonic for wallet $walletIndex');
    return mnemonic;
  }

  /// Derives the key pair at [index] on the external or change branch on
  /// demand. Never cached (M11): the returned pair carries the spendable
  /// secret as an immutable String, so callers must use it immediately and
  /// let it go out of scope.
  WormholeKeyPair _deriveKeyPair(String mnemonic, int index, {bool isChange = false}) => isChange
      ? _hdWalletService.deriveWormholeChangeAddressKeyPair(mnemonic: mnemonic, index: index)
      : _hdWalletService.deriveWormholeKeyPair(mnemonic: mnemonic, index: index);

  Future<WormholeKeyPair> keyPairAt(int index) async => _deriveKeyPair(await _mnemonic(), index);

  /// The address to show on the Receive screen: next unused index from the
  /// last persisted state (cheap — no network). [load] keeps it current.
  Future<WormholeKeyPair> receiveKeyPair() async => keyPairAt((await _readStateLocked()).nextIndex);

  /// Whether [address] is one of this wallet's derived wormhole addresses —
  /// external indices `0..nextIndex` and change indices `0..nextChangeIndex`
  /// cover every address ever shown for receiving or allocated for change.
  /// Used to block self-sends from the encrypted account.
  Future<bool> ownsAddress(String address) async {
    final state = await _readStateLocked();
    final mnemonic = await _mnemonic();
    for (int i = 0; i <= state.nextIndex; i++) {
      if (_deriveKeyPair(mnemonic, i).address == address) return true;
    }
    for (int i = 0; i <= state.nextChangeIndex; i++) {
      if (_deriveKeyPair(mnemonic, i, isChange: true).address == address) return true;
    }
    return false;
  }

  /// Drops on-disk transfer/nullifier caches for this wallet's known addresses
  /// so the next [load] re-queries from chain. Preserves pending-spend records
  /// and nextIndex — those are only pruned by [load]'s reconciliation or by
  /// the 1-hour expiry, never by a refresh.
  Future<void> discardCachedState() async {
    _log('discardCachedState: wallet $walletIndex');
    // Derive every index that can have an on-disk cache (addresses only —
    // the secret half of each pair is discarded immediately).
    final state = await _readStateLocked();
    final mnemonic = await _mnemonic();
    final addresses = [
      for (int i = 0; i <= state.nextIndex; i++) _deriveKeyPair(mnemonic, i).address,
      for (int i = 0; i <= state.nextChangeIndex; i++) _deriveKeyPair(mnemonic, i, isChange: true).address,
    ];
    if (addresses.isNotEmpty) {
      await WormholeUtxoService.clearCachesForAddresses(addresses);
    }
  }

  /// [discardCachedState] then a full [load] — pull-to-refresh entry point.
  Future<EncryptedAccountState> forceReload({
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    await discardCachedState();
    return load(onProgress: onProgress, isCancelled: isCancelled);
  }

  /// Discovers used addresses, fetches their unspent UTXOs, reconciles
  /// pending-spend records and persists the refreshed state.
  Future<EncryptedAccountState> load({WormholeProgressCallback? onProgress, IsCancelledCallback? isCancelled}) async {
    _checkNotDisposed();
    final sw = Stopwatch()..start();
    final mnemonic = await _mnemonic();

    final [usedIndices, usedChangeIndices] = await Future.wait([
      _discoveryService.discoverUsedIndices(addressAt: (i) => _deriveKeyPair(mnemonic, i).address),
      _discoveryService.discoverUsedIndices(addressAt: (i) => _deriveKeyPair(mnemonic, i, isChange: true).address),
    ]);
    _log('Discovery: used indices $usedIndices, used change indices $usedChangeIndices');

    WormholeAddressInfo infoAt(int i, {bool isChange = false}) {
      final keyPair = _deriveKeyPair(mnemonic, i, isChange: isChange);
      return WormholeAddressInfo(index: i, isChange: isChange, address: keyPair.address, secretHex: keyPair.secretHex);
    }

    final scanIndices = {0, ...usedIndices}.toList()..sort();
    final changeScanIndices = usedChangeIndices.toList()..sort();
    // Secrets live only inside this list for the duration of the UTXO fetch
    // (needed there for nullifier computation); the returned UTXOs carry no
    // secrets and this list is dropped when load() returns.
    final addresses = [
      for (final i in scanIndices) infoAt(i),
      for (final i in changeScanIndices) infoAt(i, isChange: true),
    ];

    final utxoResult = await _utxoService.getUnspentUtxos(
      addresses: addresses,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    final unspentNullifiers = utxoResult.utxos.map((u) => u.nullifierHex).toSet();
    // Change-branch entries are all discovered-used by construction; external
    // entries include index 0 even when unused, so filter those.
    final usedAddresses = {
      for (final a in addresses)
        if (a.isChange || usedIndices.contains(a.index)) a.address,
    };

    int nextAfter(Set<int> used) => used.isEmpty ? 0 : (used.reduce((a, b) => a > b ? a : b) + 1);
    final discoveredNext = nextAfter(usedIndices);
    final discoveredNextChange = nextAfter(usedChangeIndices);
    final state = await _mutateState((s) {
      final kept = <PendingSpend>[];
      for (final record in s.pendingSpends) {
        final allSpent = record.nullifiers.every((n) => !unspentNullifiers.contains(n));
        final changeArrived = record.changeAddress == null || usedAddresses.contains(record.changeAddress);
        final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(record.createdAtMs));
        if (allSpent && changeArrived) {
          _log('Pending spend confirmed on-chain, pruning (${record.nullifiers.length} nullifiers)');
        } else if (age > _pendingSpendExpiry) {
          _log('ERROR: pending spend expired unconfirmed after $age, dropping: ${record.toJson()}');
        } else {
          kept.add(record);
        }
      }
      return _FileState(
        nextIndex: s.nextIndex > discoveredNext ? s.nextIndex : discoveredNext,
        nextChangeIndex: s.nextChangeIndex > discoveredNextChange ? s.nextChangeIndex : discoveredNextChange,
        pendingSpends: kept,
      );
    });

    final pendingNullifiers = state.pendingSpends.expand((r) => r.nullifiers).toSet();
    final spendable = utxoResult.utxos.where((u) => !pendingNullifiers.contains(u.nullifierHex)).toList();
    final pendingChange = state.pendingSpends.fold(BigInt.zero, (sum, r) => sum + r.changeAmountRaw);

    _log(
      'load DONE: ${spendable.length} spendable UTXOs, pendingChange=$pendingChange, '
      'nextIndex=${state.nextIndex}, nextChangeIndex=${state.nextChangeIndex} (${sw.elapsedMilliseconds}ms)',
    );
    return EncryptedAccountState(
      utxos: spendable,
      pendingChangeRaw: pendingChange,
      totalReceivedRaw: utxoResult.totalReceivedRaw,
      changeReceivedRaw: utxoResult.changeReceivedRaw,
      totalSpentRaw: utxoResult.totalSpentRaw,
      nextIndex: state.nextIndex,
      nextChangeIndex: state.nextChangeIndex,
    );
  }

  /// Proves and submits a [plan] (from [selectWormholeInputs]) paying
  /// [recipientAddress], with change to a fresh address at the next unused
  /// index. Per submitted batch, the spent nullifiers (and change, once its
  /// batch lands) are persisted so balances stay exact even mid-flight or
  /// after a partial failure.
  Future<ClaimResult> send({
    required WormholeSpendPlan plan,
    required String recipientAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    String? rpcUrl,
  }) async {
    _checkNotDisposed();
    final changeIndex = await _reserveChangeIndex();
    // Every secret byte buffer held by this send, zeroized in the `finally`
    // below once the proofs are done (success or failure). Dart Strings
    // (secretHex) cannot be overwritten, so secrets are re-derived straight
    // into these buffers and never cached (M11).
    final secretBuffers = <Uint8List>[];
    try {
      final mnemonic = await _mnemonic();
      final changeKeyPair = _deriveKeyPair(mnemonic, changeIndex, isChange: true);
      final recipientBytes = Uint8List.fromList(getAccountId32(recipientAddress));
      final changeBytes = Uint8List.fromList(getAccountId32(changeKeyPair.address));
      _log(
        'send: ${plan.inputCount} inputs in ${plan.batches.length} batches, '
        'amount=${plan.amountRaw}, change=${plan.changeRaw} -> change index $changeIndex',
      );

      // UTXOs carry no secrets (see WormholeUtxoService.getUnspentUtxos), so
      // each input's secret is re-derived from its owner's HD branch and index.
      Uint8List secretAt(WormholeAddressInfo owner) {
        final keyPair = _deriveKeyPair(mnemonic, owner.index, isChange: owner.isChange);
        final secret = Uint8List.fromList(hex.decode(keyPair.secretHex.replaceFirst('0x', '')));
        secretBuffers.add(secret);
        return secret;
      }

      final batches = [
        for (final batch in plan.batches)
          [
            for (final a in batch)
              WormholeLeafSpend(
                transfer: a.utxo.transfer,
                secret: secretAt(a.utxo.owner),
                exitAccount1: recipientBytes,
                outputAmount1: a.recipientScaled,
                exitAccount2: a.changeScaled > 0 ? changeBytes : null,
                outputAmount2: a.changeScaled,
              ),
          ],
      ];

      return await _sendService.sendSpends(
        batches: batches,
        circuitBinsDir: circuitBinsDir,
        onProgress: onProgress,
        rpcUrl: rpcUrl,
        onBatchSubmitted: (batchIndex, nullifiers) async {
          final changeScaled = plan.batches[batchIndex].fold<int>(0, (sum, a) => sum + a.changeScaled);
          final hasChange = changeScaled > 0;
          await _mutateState(
            (s) => _FileState(
              nextIndex: s.nextIndex,
              nextChangeIndex: hasChange && changeIndex >= s.nextChangeIndex ? changeIndex + 1 : s.nextChangeIndex,
              pendingSpends: [
                ...s.pendingSpends,
                PendingSpend(
                  nullifiers: nullifiers,
                  changeAddress: hasChange ? changeKeyPair.address : null,
                  changeAmountRaw: wormholeRawFromScaled(changeScaled),
                  createdAtMs: DateTime.now().millisecondsSinceEpoch,
                ),
              ],
            ),
          );
          _log('Batch $batchIndex recorded: ${nullifiers.length} nullifiers spent, change=$hasChange');
        },
      );
    } finally {
      for (final secret in secretBuffers) {
        secret.fillRange(0, secret.length, 0);
      }
      // By now either a change-bearing batch bumped the persisted
      // nextChangeIndex past the reservation, or the send failed and the
      // index is free again.
      _reservedChangeIndices.remove(changeIndex);
    }
  }

  Future<void> cancel() => _sendService.cancel();

  // --- Persistent state ---

  Future<File> _stateFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/encrypted_account_w$walletIndex.json');
  }

  /// Deletes every wallet's encrypted-account state file (next-index / pending
  /// spends). Call on logout; otherwise a new wallet at the same index inherits
  /// pending-change balance from the previous session.
  static Future<void> clearAllPersistedState() async {
    // Quiesce in-flight loads/sends first: without this, a delayed
    // onBatchSubmitted or load() reconciliation could recreate the state file
    // right after it is deleted below.
    await disposeAll();
    try {
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) return;
      var deleted = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last;
        if (name.startsWith('encrypted_account_w') && (name.endsWith('.json') || name.endsWith('.json.tmp'))) {
          await entity.delete();
          deleted++;
        }
      }
      _log('clearAllPersistedState: deleted $deleted file(s)');
    } catch (e) {
      _log('clearAllPersistedState failed (non-fatal): $e');
    }
  }

  Future<_FileState> _readState() async {
    final file = await _stateFile();
    if (!await file.exists()) return const _FileState(nextIndex: 0, nextChangeIndex: 0, pendingSpends: []);
    return _FileState.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  }

  /// Serializes [action] behind every queued state mutation. All reads that
  /// inform writes (and all writes) go through this, so nothing can observe
  /// state mid-mutation.
  Future<T> _withStateLock<T>(Future<T> Function() action) {
    final result = _stateLock.then((_) => action());
    _stateLock = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<_FileState> _readStateLocked() => _withStateLock(_readState);

  /// Claims the change-branch index for a new send: the persisted next unused
  /// change index, skipping indices already reserved by other in-flight sends.
  Future<int> _reserveChangeIndex() => _withStateLock(() async {
    var index = (await _readState()).nextChangeIndex;
    while (_reservedChangeIndices.contains(index)) {
      index++;
    }
    _reservedChangeIndices.add(index);
    return index;
  });

  Future<_FileState> _mutateState(_FileState Function(_FileState) fn) => _withStateLock(() async {
    // Re-checked under the lock: after logout ([dispose]) a delayed callback
    // from an old load()/send() must fail here rather than resurrect the
    // previous session's state on disk.
    _checkNotDisposed();
    final next = fn(await _readState());
    final file = await _stateFile();
    // Write-then-rename so a concurrent reader can never observe a torn file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(next.toJson()), flush: true);
    await tmp.rename(file.path);
    return next;
  });
}

/// A submitted-but-not-yet-indexed spend: its input nullifiers are excluded
/// from the spendable set and its change is counted as pending balance until
/// the indexer confirms both.
class PendingSpend {
  final List<String> nullifiers;
  final String? changeAddress;
  final BigInt changeAmountRaw;
  final int createdAtMs;

  const PendingSpend({
    required this.nullifiers,
    required this.changeAddress,
    required this.changeAmountRaw,
    required this.createdAtMs,
  });

  factory PendingSpend.fromJson(Map<String, dynamic> json) => PendingSpend(
    nullifiers: (json['nullifiers'] as List<dynamic>).cast<String>(),
    changeAddress: json['changeAddress'] as String?,
    changeAmountRaw: BigInt.parse(json['changeAmountRaw'] as String),
    createdAtMs: json['createdAtMs'] as int,
  );

  Map<String, dynamic> toJson() => {
    'nullifiers': nullifiers,
    'changeAddress': changeAddress,
    'changeAmountRaw': changeAmountRaw.toString(),
    'createdAtMs': createdAtMs,
  };
}

class _FileState {
  final int nextIndex;
  final int nextChangeIndex;
  final List<PendingSpend> pendingSpends;

  const _FileState({required this.nextIndex, required this.nextChangeIndex, required this.pendingSpends});

  factory _FileState.fromJson(Map<String, dynamic> json) => _FileState(
    nextIndex: json['nextIndex'] as int,
    // Absent in files written before change moved to its own branch; those
    // wallets' old change addresses live on the external branch and stay
    // covered by nextIndex.
    nextChangeIndex: json['nextChangeIndex'] as int? ?? 0,
    pendingSpends: (json['pendingSpends'] as List<dynamic>)
        .map((e) => PendingSpend.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'nextIndex': nextIndex,
    'nextChangeIndex': nextChangeIndex,
    'pendingSpends': pendingSpends.map((e) => e.toJson()).toList(),
  };
}
