import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quantus_sdk/src/models/transaction_event.dart';
import 'package:quantus_sdk/src/services/account_discovery_service.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart' show getAccountId32;
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_history.dart';
import 'package:quantus_sdk/src/services/wormhole_send_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

typedef MnemonicGetter = Future<String?> Function();

/// Snapshot of an encrypted account: everything the indexer holds for its
/// wormhole addresses, the spendable remainder, and change that has been
/// submitted but not yet indexed.
class EncryptedAccountState {
  /// External index 0 — the address the account is known by.
  final String accountId;

  /// Every address of this account a spend of its own may have paid change to.
  final Set<String> ownAddresses;
  final List<WormholeUtxo> received;
  final Map<String, WormholeSpend> spends;

  /// [received] minus on-chain spends and in-flight pending spends.
  final List<WormholeUtxo> utxos;
  final BigInt pendingChangeToken;

  /// Next unused external index — shown as the receive address.
  final int nextIndex;

  /// Next unused change-branch index — allocated as the change address of the
  /// next send.
  final int nextChangeIndex;

  /// When the scan behind this snapshot finished.
  final DateTime loadedAt;

  EncryptedAccountState({
    required this.accountId,
    required this.ownAddresses,
    required this.received,
    required this.spends,
    required this.utxos,
    required this.pendingChangeToken,
    required this.nextIndex,
    required this.nextChangeIndex,
    DateTime? loadedAt,
  }) : loadedAt = loadedAt ?? DateTime.now();

  /// Whether every planned input is still among the spendable UTXOs.
  bool canSpend(WormholeSpendPlan plan) {
    final spendable = utxos.map((u) => u.nullifierHex).toSet();
    return plan.batches.every((batch) => batch.inputs.every((u) => spendable.contains(u.nullifierHex)));
  }

  /// Funds a send can draw on right now: the spendable UTXOs, before the
  /// volume fee.
  BigInt get availableToken => utxos.fold(BigInt.zero, (sum, u) => sum + u.amount);

  BigInt get balance => availableToken + pendingChangeToken;

  /// Max amount sendable right now (post volume fee, excluding pending change).
  BigInt get maxSendable => wormholeMaxSendable(utxos);

  List<TransactionEvent> history() =>
      buildWormholeHistory(accountId: accountId, ownAddresses: ownAddresses, received: received, spends: spends);
}

/// An encrypted account: two HD sequences of wormhole addresses treated as a
/// single pool of funds — an external branch (`m/44'/189189189'/0'/0'/n'`)
/// whose next unused index is shown for receiving, and a change branch
/// (`m/44'/189189189'/0'/1'/n'`) whose next unused indices are consumed as
/// the fresh change addresses of each send — one per bill or remainder the
/// send returns ([WormholeBatchPlan]). Both branches are gap-limit scanned
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

  /// The scan currently running, if any; see [load].
  Future<EncryptedAccountState>? _inFlightLoad;

  /// Change indices claimed by in-flight sends, so two overlapping sends can
  /// never allocate the same change address. Released when the send finishes
  /// (by then a change-bearing batch has bumped the persisted next index).
  final Set<int> _reservedChangeIndices = {};

  /// Every not-yet-disposed instance, so logout can quiesce all in-flight
  /// encrypted work ([disposeAll]) before session state is wiped.
  static final Set<EncryptedAccountService> _live = {};

  /// Addresses derived so far on each branch, by index. Addresses are public
  /// (they are the `to_id` of on-chain transfers) and deterministic for this
  /// wallet, so unlike key pairs they may be kept for the session: a load
  /// derives each address once and [ownsAddress] / [discardCachedState] then
  /// cost nothing. Holds no secret (M11).
  ///
  /// The book — like the persisted state file — belongs to one seed,
  /// identified by its external address 0 ([_addressBookOwner]). A wallet
  /// slot can be reused for a different seed (delete a wallet, import
  /// another), so every entry point re-checks the owner ([_bindToSeed]) and
  /// starts over when it changed.
  final Map<int, String> _externalAddresses = {};
  final Map<int, String> _changeAddresses = {};
  String? _addressBookOwner;

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

  /// Makes the address book and the persisted state the ones for [mnemonic],
  /// discarding what a seed that previously occupied this wallet slot left
  /// behind. Without this the new seed would hand out the old seed's next
  /// receive and change indices, which can lie past the gap limit where
  /// discovery never looks.
  Future<void> _bindToSeed(String mnemonic) async {
    final owner = (await _hdWalletService.deriveWormholeAddresses(mnemonic: mnemonic, indices: const [0])).single;
    if (owner == _addressBookOwner) return;
    if (_addressBookOwner != null) _log('address book: seed changed for wallet $walletIndex, rebuilding');
    _externalAddresses
      ..clear()
      ..[0] = owner;
    _changeAddresses.clear();
    _addressBookOwner = owner;
    await _withStateLock(() async {
      // No file yet: the first mutation stamps the owner ([_mutateState]).
      if (!await (await _stateFile()).exists()) return;
      final s = await _readState();
      if (s.owner == owner) return;
      _checkNotDisposed();
      if (s.owner == null) {
        // Written before state files recorded their seed: adopt it.
        await _writeState(s.withOwner(owner));
        return;
      }
      _log('persisted state for wallet $walletIndex belongs to another seed; starting over');
      await _writeState(_FileState(owner: owner, nextIndex: 0, nextChangeIndex: 0, pendingSpends: const []));
    });
  }

  /// Addresses at [indices] on one branch, in order. Indices not yet in the
  /// address book are derived together (one seed stretch) and remembered.
  /// Callers bind to [mnemonic] first ([_bindToSeed]).
  Future<List<String>> _addressesAt(String mnemonic, List<int> indices, {required bool isChange}) async {
    final book = isChange ? _changeAddresses : _externalAddresses;
    final missing = [
      for (final i in indices)
        if (!book.containsKey(i)) i,
    ];
    if (missing.isNotEmpty) {
      final derived = await _hdWalletService.deriveWormholeAddresses(
        mnemonic: mnemonic,
        indices: missing,
        isChange: isChange,
      );
      for (var k = 0; k < missing.length; k++) {
        book[missing[k]] = derived[k];
      }
    }
    return [for (final i in indices) book[i]!];
  }

  Future<List<String>> _addressesUpTo(String mnemonic, int lastIndex, {required bool isChange}) =>
      _addressesAt(mnemonic, [for (var i = 0; i <= lastIndex; i++) i], isChange: isChange);

  /// The address to show on the Receive screen: next unused index from the
  /// last persisted state (cheap — no network). [load] keeps it current.
  Future<WormholeKeyPair> receiveKeyPair() async {
    final mnemonic = await _mnemonic();
    await _bindToSeed(mnemonic);
    return _deriveKeyPair(mnemonic, (await _readStateLocked()).nextIndex);
  }

  /// Whether [address] is one of this wallet's derived wormhole addresses —
  /// external indices `0..nextIndex` and change indices `0..nextChangeIndex`
  /// cover every address ever shown for receiving or allocated for change.
  /// Used to block self-sends from the encrypted account.
  Future<bool> ownsAddress(String address) async {
    final mnemonic = await _mnemonic();
    await _bindToSeed(mnemonic);
    final state = await _readStateLocked();
    final external = await _addressesUpTo(mnemonic, state.nextIndex, isChange: false);
    if (external.contains(address)) return true;
    final change = await _addressesUpTo(mnemonic, state.nextChangeIndex, isChange: true);
    return change.contains(address);
  }

  /// Drops on-disk transfer/nullifier caches for this wallet's known addresses
  /// so the next [load] re-queries from chain. Preserves pending-spend records
  /// and nextIndex — those are only pruned by [load]'s reconciliation or by
  /// the 1-hour expiry, never by a refresh.
  Future<void> discardCachedState() async {
    _log('discardCachedState: wallet $walletIndex');
    // A scan in flight would write the caches back right after the wipe;
    // let it finish first (its outcome is the caller's concern, not ours).
    final inFlight = _inFlightLoad;
    if (inFlight != null) await inFlight.then<void>((_) {}, onError: (_) {});
    // Every index that can have an on-disk cache.
    final mnemonic = await _mnemonic();
    await _bindToSeed(mnemonic);
    final state = await _readStateLocked();
    final addresses = [
      ...await _addressesUpTo(mnemonic, state.nextIndex, isChange: false),
      ...await _addressesUpTo(mnemonic, state.nextChangeIndex, isChange: true),
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
  ///
  /// One scan at a time: a call made while another is in flight joins it and
  /// receives the same result, so the poll, a provider rebuild and a send's
  /// pre-flight check never run the discovery and indexer walk side by side
  /// (or race each other writing the same cache files). Only the first
  /// caller's [onProgress] / [isCancelled] are honoured.
  Future<EncryptedAccountState> load({WormholeProgressCallback? onProgress, IsCancelledCallback? isCancelled}) async {
    _checkNotDisposed();
    final inFlight = _inFlightLoad;
    if (inFlight != null) {
      _log('load: joining the scan already in flight');
      return inFlight;
    }
    final run = _load(onProgress: onProgress, isCancelled: isCancelled);
    _inFlightLoad = run;
    try {
      return await run;
    } finally {
      if (identical(_inFlightLoad, run)) _inFlightLoad = null;
    }
  }

  Future<EncryptedAccountState> _load({WormholeProgressCallback? onProgress, IsCancelledCallback? isCancelled}) async {
    final sw = Stopwatch()..start();
    final mnemonic = await _mnemonic();
    await _bindToSeed(mnemonic);

    // Gap-limit discovery of both branches — the only thing that finds
    // addresses this device has never seen (recovery from the mnemonic), so
    // it always runs; the persisted next indices size its first probe and
    // the address book makes each batch cheaper.
    final persisted = await _readStateLocked();
    final [usedIndices, usedChangeIndices] = await Future.wait([
      _discoveryService.discoverUsedIndicesBatched(
        addressesAt: (indices) => _addressesAt(mnemonic, indices, isChange: false),
        knownLength: persisted.nextIndex,
      ),
      _discoveryService.discoverUsedIndicesBatched(
        addressesAt: (indices) => _addressesAt(mnemonic, indices, isChange: true),
        knownLength: persisted.nextChangeIndex,
      ),
    ]);
    _log('Discovery: used indices $usedIndices, used change indices $usedChangeIndices');

    // Change addresses this device allocated itself are scanned whether or
    // not discovery has seen them yet: the change of a send just submitted
    // is found as soon as its transfer is indexed, instead of one indexer
    // pass later when the address shows up in the account table.
    final allocatedChangeIndices = persisted.nextChangeIndex;
    final scanIndices = {0, ...usedIndices}.toList()..sort();
    final changeScanIndices = {...usedChangeIndices, for (var i = 0; i < allocatedChangeIndices; i++) i}.toList()
      ..sort();
    // One seed stretch per branch for the used indices' secrets. Secrets live
    // only inside this list for the duration of the UTXO fetch (needed there
    // for nullifier computation); the returned UTXOs carry no secrets and this
    // list is dropped when load() returns.
    final [externalPairs, changePairs] = await Future.wait([
      _hdWalletService.deriveWormholeKeyPairs(mnemonic: mnemonic, indices: scanIndices),
      _hdWalletService.deriveWormholeKeyPairs(mnemonic: mnemonic, indices: changeScanIndices, isChange: true),
    ]);
    final addresses = [
      for (var k = 0; k < scanIndices.length; k++)
        WormholeAddressInfo(
          index: scanIndices[k],
          address: externalPairs[k].address,
          secretHex: externalPairs[k].secretHex,
        ),
      for (var k = 0; k < changeScanIndices.length; k++)
        WormholeAddressInfo(
          index: changeScanIndices[k],
          isChange: true,
          address: changePairs[k].address,
          secretHex: changePairs[k].secretHex,
        ),
    ];

    final utxoResult = await _utxoService.getUnspentUtxos(
      addresses: addresses,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    final spends = utxoResult.spends;
    final receivedAddresses = {for (final u in utxoResult.received) u.owner.address};
    bool changeArrivedFor(PendingSpend record) =>
        record.changeOutputs.every((output) => receivedAddresses.contains(output.address));

    int nextAfter(Set<int> used) => used.isEmpty ? 0 : (used.reduce((a, b) => a > b ? a : b) + 1);
    final discoveredNext = nextAfter(usedIndices);
    final discoveredNextChange = nextAfter(usedChangeIndices);
    final state = await _mutateState((s) {
      final kept = <PendingSpend>[];
      for (final record in s.pendingSpends) {
        final allSpent = record.nullifiers.every(spends.containsKey);
        final changeArrived = changeArrivedFor(record);
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
        owner: s.owner,
        nextIndex: s.nextIndex > discoveredNext ? s.nextIndex : discoveredNext,
        nextChangeIndex: s.nextChangeIndex > discoveredNextChange ? s.nextChangeIndex : discoveredNextChange,
        pendingSpends: kept,
      );
    });

    final pendingNullifiers = state.pendingSpends.expand((r) => r.nullifiers).toSet();
    final spendable = utxoResult.utxos.where((u) => !pendingNullifiers.contains(u.nullifierHex)).toList();
    // Change that has already arrived is in [spendable]; a record kept only
    // because its inputs are not yet reported spent must not count it twice.
    final pendingChange = state.pendingSpends
        .where((r) => !changeArrivedFor(r))
        .fold(BigInt.zero, (sum, r) => sum + r.changeAmountToken);
    // A send landing mid-load allocates a change index past the ones scanned
    // above; its spend must still classify as change.
    final ownAddresses = {
      for (final a in addresses) a.address,
      if (state.nextChangeIndex > 0) ...await _addressesUpTo(mnemonic, state.nextChangeIndex - 1, isChange: true),
    };

    _log(
      'load DONE: ${spendable.length} spendable UTXOs, pendingChange=$pendingChange, '
      'nextIndex=${state.nextIndex}, nextChangeIndex=${state.nextChangeIndex} (${sw.elapsedMilliseconds}ms)',
    );
    return EncryptedAccountState(
      accountId: addresses.first.address,
      ownAddresses: ownAddresses,
      received: utxoResult.received,
      spends: spends,
      utxos: spendable,
      pendingChangeToken: pendingChange,
      nextIndex: state.nextIndex,
      nextChangeIndex: state.nextChangeIndex,
    );
  }

  /// Proves and submits a [plan] (from [selectWormholeInputs]) paying
  /// [recipientAddress], with each bill and remainder of its change to its
  /// own fresh address at the next unused change indices. Per submitted
  /// batch, the spent nullifiers (and that batch's change outputs) are
  /// persisted so balances stay exact even mid-flight or after a partial
  /// failure.
  Future<ClaimResult> send({
    required WormholeSpendPlan plan,
    required String recipientAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    String? rpcUrl,
  }) async {
    _checkNotDisposed();
    final mnemonic = await _mnemonic();
    await _bindToSeed(mnemonic);
    final changeIndices = await _reserveChangeIndices(plan.changeOutputCount);
    // Every secret byte buffer held by this send, zeroized in the `finally`
    // below once the proofs are done (success or failure). Dart Strings
    // (secretHex) cannot be overwritten, so secrets are re-derived straight
    // into these buffers and never cached (M11).
    final secretBuffers = <Uint8List>[];
    try {
      final changeAddresses = [for (final i in changeIndices) _deriveKeyPair(mnemonic, i, isChange: true).address];
      final recipientBytes = Uint8List.fromList(getAccountId32(recipientAddress));
      _log(
        'send: ${plan.inputCount} inputs in ${plan.batches.length} batches, '
        'amount=${plan.amountToken}, change=${plan.changeToken} in ${changeAddresses.length} outputs '
        '-> change indices $changeIndices',
      );

      // UTXOs carry no secrets (see WormholeUtxoService.getUnspentUtxos), so
      // each input's secret is re-derived from its owner's HD branch and index.
      Uint8List secretAt(WormholeAddressInfo owner) {
        final keyPair = _deriveKeyPair(mnemonic, owner.index, isChange: owner.isChange);
        final secret = Uint8List.fromList(hex.decode(keyPair.secretHex.replaceFirst('0x', '')));
        secretBuffers.add(secret);
        return secret;
      }

      // Change outputs of consecutive batches take consecutive addresses.
      var nextChange = 0;
      final changeOutputsByBatch = <List<PendingChangeOutput>>[];
      final batches = <WormholeBatchSpend>[];
      for (final batch in plan.batches) {
        final changeOutputs = [
          for (final amount in batch.changeExitsScaled)
            PendingChangeOutput(address: changeAddresses[nextChange++], amountToken: wormholeTokenFromScaled(amount)),
        ];
        changeOutputsByBatch.add(changeOutputs);
        batches.add(
          WormholeBatchSpend(
            burns: [
              for (final utxo in batch.inputs) WormholeBurn(transfer: utxo.transfer, secret: secretAt(utxo.owner)),
            ],
            exits: [
              if (batch.recipientScaled > 0) WormholeExit(account: recipientBytes, amountScaled: batch.recipientScaled),
              for (final output in changeOutputs)
                WormholeExit(
                  account: Uint8List.fromList(getAccountId32(output.address)),
                  amountScaled: wormholeScaledFromToken(output.amountToken),
                  returnsToSender: true,
                ),
            ],
          ),
        );
      }

      // The highest change index each batch uses; a submitted batch moves
      // the persisted next index past it.
      final lastChangeIndexByBatch = <int?>[];
      var used = 0;
      for (final outputs in changeOutputsByBatch) {
        used += outputs.length;
        lastChangeIndexByBatch.add(outputs.isEmpty ? null : changeIndices[used - 1]);
      }

      return await _sendService.sendSpends(
        batches: batches,
        circuitBinsDir: circuitBinsDir,
        onProgress: onProgress,
        rpcUrl: rpcUrl,
        onBatchSubmitted: (batchIndex, nullifiers) async {
          final changeOutputs = changeOutputsByBatch[batchIndex];
          final lastChangeIndex = lastChangeIndexByBatch[batchIndex];
          await _mutateState(
            (s) => _FileState(
              owner: s.owner,
              nextIndex: s.nextIndex,
              nextChangeIndex: lastChangeIndex != null && lastChangeIndex >= s.nextChangeIndex
                  ? lastChangeIndex + 1
                  : s.nextChangeIndex,
              pendingSpends: [
                ...s.pendingSpends,
                PendingSpend(
                  nullifiers: nullifiers,
                  changeOutputs: changeOutputs,
                  createdAtMs: DateTime.now().millisecondsSinceEpoch,
                ),
              ],
            ),
          );
          _log(
            'Batch $batchIndex recorded: ${nullifiers.length} nullifiers spent, '
            '${changeOutputs.length} change outputs',
          );
        },
      );
    } finally {
      for (final secret in secretBuffers) {
        secret.fillRange(0, secret.length, 0);
      }
      // By now either a change-bearing batch bumped the persisted
      // nextChangeIndex past the reservations, or the send failed and the
      // indices are free again.
      _reservedChangeIndices.removeAll(changeIndices);
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

  /// Claims [count] change-branch indices for a new send: the persisted next
  /// unused change index onwards, skipping indices already reserved by other
  /// in-flight sends.
  Future<List<int>> _reserveChangeIndices(int count) => _withStateLock(() async {
    final indices = <int>[];
    var index = (await _readState()).nextChangeIndex;
    while (indices.length < count) {
      if (!_reservedChangeIndices.contains(index)) {
        _reservedChangeIndices.add(index);
        indices.add(index);
      }
      index++;
    }
    return indices;
  });

  Future<_FileState> _mutateState(_FileState Function(_FileState) fn) => _withStateLock(() async {
    // Re-checked under the lock: after logout ([dispose]) a delayed callback
    // from an old load()/send() must fail here rather than resurrect the
    // previous session's state on disk.
    _checkNotDisposed();
    var next = fn(await _readState());
    if (next.owner == null && _addressBookOwner != null) next = next.withOwner(_addressBookOwner!);
    await _writeState(next);
    return next;
  });

  /// Only under [_withStateLock].
  Future<void> _writeState(_FileState state) async {
    final file = await _stateFile();
    // Write-then-rename so a concurrent reader can never observe a torn file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

/// One change exit of a submitted spend: a bill or remainder paid to one of
/// the wallet's fresh change addresses.
class PendingChangeOutput {
  final String address;
  final BigInt amountToken;

  const PendingChangeOutput({required this.address, required this.amountToken});

  factory PendingChangeOutput.fromJson(Map<String, dynamic> json) =>
      PendingChangeOutput(address: json['address'] as String, amountToken: BigInt.parse(json['amountToken'] as String));

  Map<String, dynamic> toJson() => {'address': address, 'amountToken': amountToken.toString()};
}

/// A submitted-but-not-yet-indexed spend: its input nullifiers are excluded
/// from the spendable set and its change is counted as pending balance until
/// the indexer confirms both.
class PendingSpend {
  final List<String> nullifiers;
  final List<PendingChangeOutput> changeOutputs;
  final int createdAtMs;

  const PendingSpend({required this.nullifiers, required this.changeOutputs, required this.createdAtMs});

  BigInt get changeAmountToken => changeOutputs.fold(BigInt.zero, (sum, o) => sum + o.amountToken);

  /// Reads the current shape or one written before change was denominated,
  /// which recorded a single `changeAddress` / `changeAmountToken` (or
  /// `changeAmountPlanck`, before the planck -> token rename).
  factory PendingSpend.fromJson(Map<String, dynamic> json) {
    final outputs = json['changeOutputs'] as List<dynamic>?;
    final legacyAddress = json['changeAddress'] as String?;
    return PendingSpend(
      nullifiers: (json['nullifiers'] as List<dynamic>).cast<String>(),
      changeOutputs: outputs != null
          ? [for (final o in outputs) PendingChangeOutput.fromJson(o as Map<String, dynamic>)]
          : [
              if (legacyAddress != null)
                PendingChangeOutput(
                  address: legacyAddress,
                  amountToken: BigInt.parse((json['changeAmountToken'] ?? json['changeAmountPlanck']) as String),
                ),
            ],
      createdAtMs: json['createdAtMs'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'nullifiers': nullifiers,
    'changeOutputs': changeOutputs.map((o) => o.toJson()).toList(),
    'createdAtMs': createdAtMs,
  };
}

class _FileState {
  /// External address 0 of the seed this state belongs to; null in files
  /// written before it was recorded.
  final String? owner;
  final int nextIndex;
  final int nextChangeIndex;
  final List<PendingSpend> pendingSpends;

  const _FileState({this.owner, required this.nextIndex, required this.nextChangeIndex, required this.pendingSpends});

  _FileState withOwner(String owner) =>
      _FileState(owner: owner, nextIndex: nextIndex, nextChangeIndex: nextChangeIndex, pendingSpends: pendingSpends);

  factory _FileState.fromJson(Map<String, dynamic> json) => _FileState(
    owner: json['owner'] as String?,
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
    'owner': ?owner,
    'nextIndex': nextIndex,
    'nextChangeIndex': nextChangeIndex,
    'pendingSpends': pendingSpends.map((e) => e.toJson()).toList(),
  };
}
