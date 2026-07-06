import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quantus_sdk/src/services/account_discovery_service.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart' show getAccountId32;
import 'package:quantus_sdk/src/services/wormhole_address_manager.dart' show MnemonicGetter;
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_send_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

/// Snapshot of an encrypted account: spendable UTXOs across all discovered
/// wormhole addresses, plus change that has been submitted but not yet indexed.
class EncryptedAccountState {
  final List<WormholeUtxo> utxos;
  final BigInt pendingChangePlanck;

  /// Next unused address index — shown as the receive address and allocated
  /// as the change address of the next send.
  final int nextIndex;

  const EncryptedAccountState({required this.utxos, required this.pendingChangePlanck, required this.nextIndex});

  BigInt get balance => utxos.fold(BigInt.zero, (sum, u) => sum + u.amount) + pendingChangePlanck;

  /// Max amount sendable right now (post volume fee, excluding pending change).
  BigInt get maxSendable => wormholeMaxSendable(utxos);
}

/// An encrypted account: one linear HD sequence of wormhole addresses
/// (`m/44'/189189189'/0'/0'/n'`) treated as a single pool of funds.
///
/// Receive and change share the sequence — the next unused index is shown for
/// receiving and consumed as the fresh change address of the next send, so a
/// gap-limit scan (same algorithm as transparent accounts) rediscovers all
/// funds from the mnemonic alone. Spent inputs are excluded via on-chain
/// nullifiers; in-flight sends are bridged by locally persisted pending-spend
/// records until the indexer catches up.
class EncryptedAccountService {
  static const Duration _pendingSpendExpiry = Duration(hours: 1);

  final int walletIndex;
  final MnemonicGetter _getMnemonic;
  final HdWalletService _hdWalletService;
  final WormholeUtxoService _utxoService;
  final AccountDiscoveryService _discoveryService;
  final WormholeSendService _sendService;

  final Map<int, WormholeKeyPair> _keyPairs = {};
  Future<void> _stateLock = Future.value();

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
       _sendService = sendService ?? WormholeSendService();

  // ignore: avoid_print
  static void _log(String msg) => print('[EncryptedAccount] $msg');

  Future<String> _mnemonic() async {
    final mnemonic = await _getMnemonic();
    if (mnemonic == null) throw StateError('No mnemonic for wallet $walletIndex');
    return mnemonic;
  }

  WormholeKeyPair _keyPairAtSync(String mnemonic, int index) =>
      _keyPairs[index] ??= _hdWalletService.deriveWormholeKeyPair(mnemonic: mnemonic, index: index);

  Future<WormholeKeyPair> keyPairAt(int index) async => _keyPairAtSync(await _mnemonic(), index);

  /// The address to show on the Receive screen: next unused index from the
  /// last persisted state (cheap — no network). [load] keeps it current.
  Future<WormholeKeyPair> receiveKeyPair() async => keyPairAt((await _readState()).nextIndex);

  /// Discovers used addresses, fetches their unspent UTXOs, reconciles
  /// pending-spend records and persists the refreshed state.
  Future<EncryptedAccountState> load({WormholeProgressCallback? onProgress, IsCancelledCallback? isCancelled}) async {
    final sw = Stopwatch()..start();
    final mnemonic = await _mnemonic();

    final usedIndices = await _discoveryService.discoverUsedIndices(
      addressAt: (i) => _keyPairAtSync(mnemonic, i).address,
    );
    _log('Discovery: used indices $usedIndices');

    final scanIndices = {0, ...usedIndices}.toList()..sort();
    final addresses = [
      for (final i in scanIndices)
        WormholeAddressInfo(
          index: i,
          address: _keyPairAtSync(mnemonic, i).address,
          secretHex: _keyPairAtSync(mnemonic, i).secretHex,
        ),
    ];

    final utxos = await _utxoService.getUnspentUtxos(
      addresses: addresses,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    final unspentNullifiers = utxos.map((u) => u.nullifierHex).toSet();
    final usedAddresses = {for (final i in usedIndices) _keyPairAtSync(mnemonic, i).address};

    final discoveredNext = usedIndices.isEmpty ? 0 : (usedIndices.reduce((a, b) => a > b ? a : b) + 1);
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
        pendingSpends: kept,
      );
    });

    final pendingNullifiers = state.pendingSpends.expand((r) => r.nullifiers).toSet();
    final spendable = utxos.where((u) => !pendingNullifiers.contains(u.nullifierHex)).toList();
    final pendingChange = state.pendingSpends.fold(BigInt.zero, (sum, r) => sum + r.changeAmountPlanck);

    _log(
      'load DONE: ${spendable.length} spendable UTXOs, pendingChange=$pendingChange, '
      'nextIndex=${state.nextIndex} (${sw.elapsedMilliseconds}ms)',
    );
    return EncryptedAccountState(
      utxos: spendable,
      pendingChangePlanck: pendingChange,
      nextIndex: state.nextIndex,
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
    final changeIndex = (await _readState()).nextIndex;
    final changeKeyPair = await keyPairAt(changeIndex);
    final recipientBytes = Uint8List.fromList(getAccountId32(recipientAddress));
    final changeBytes = Uint8List.fromList(getAccountId32(changeKeyPair.address));
    _log(
      'send: ${plan.inputCount} inputs in ${plan.batches.length} batches, '
      'amount=${plan.amountPlanck}, change=${plan.changePlanck} -> index $changeIndex',
    );

    final batches = [
      for (final batch in plan.batches)
        [
          for (final a in batch)
            WormholeLeafSpend(
              transfer: a.utxo.transfer,
              secret: Uint8List.fromList(hex.decode(a.utxo.owner.secretHex.replaceFirst('0x', ''))),
              exitAccount1: recipientBytes,
              outputAmount1: a.recipientScaled,
              exitAccount2: a.changeScaled > 0 ? changeBytes : null,
              outputAmount2: a.changeScaled,
            ),
        ],
    ];

    return _sendService.sendSpends(
      batches: batches,
      circuitBinsDir: circuitBinsDir,
      onProgress: onProgress,
      rpcUrl: rpcUrl,
      onBatchSubmitted: (batchIndex, nullifiers) async {
        final changeScaled = plan.batches[batchIndex].fold<int>(0, (sum, a) => sum + a.changeScaled);
        final hasChange = changeScaled > 0;
        await _mutateState(
          (s) => _FileState(
            nextIndex: hasChange && changeIndex >= s.nextIndex ? changeIndex + 1 : s.nextIndex,
            pendingSpends: [
              ...s.pendingSpends,
              PendingSpend(
                nullifiers: nullifiers,
                changeAddress: hasChange ? changeKeyPair.address : null,
                changeAmountPlanck: wormholePlanckFromScaled(changeScaled),
                createdAtMs: DateTime.now().millisecondsSinceEpoch,
              ),
            ],
          ),
        );
        _log('Batch $batchIndex recorded: ${nullifiers.length} nullifiers spent, change=$hasChange');
      },
    );
  }

  void cancel() => _sendService.cancel();

  // --- Persistent state ---

  Future<File> _stateFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/encrypted_account_w$walletIndex.json');
  }

  Future<_FileState> _readState() async {
    final file = await _stateFile();
    if (!await file.exists()) return const _FileState(nextIndex: 0, pendingSpends: []);
    return _FileState.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  }

  Future<_FileState> _mutateState(_FileState Function(_FileState) fn) {
    final result = _stateLock.then((_) async {
      final next = fn(await _readState());
      final file = await _stateFile();
      await file.writeAsString(jsonEncode(next.toJson()));
      return next;
    });
    _stateLock = result.then((_) {}, onError: (_) {});
    return result;
  }
}

/// A submitted-but-not-yet-indexed spend: its input nullifiers are excluded
/// from the spendable set and its change is counted as pending balance until
/// the indexer confirms both.
class PendingSpend {
  final List<String> nullifiers;
  final String? changeAddress;
  final BigInt changeAmountPlanck;
  final int createdAtMs;

  const PendingSpend({
    required this.nullifiers,
    required this.changeAddress,
    required this.changeAmountPlanck,
    required this.createdAtMs,
  });

  factory PendingSpend.fromJson(Map<String, dynamic> json) => PendingSpend(
    nullifiers: (json['nullifiers'] as List<dynamic>).cast<String>(),
    changeAddress: json['changeAddress'] as String?,
    changeAmountPlanck: BigInt.parse(json['changeAmountPlanck'] as String),
    createdAtMs: json['createdAtMs'] as int,
  );

  Map<String, dynamic> toJson() => {
    'nullifiers': nullifiers,
    'changeAddress': changeAddress,
    'changeAmountPlanck': changeAmountPlanck.toString(),
    'createdAtMs': createdAtMs,
  };
}

class _FileState {
  final int nextIndex;
  final List<PendingSpend> pendingSpends;

  const _FileState({required this.nextIndex, required this.pendingSpends});

  factory _FileState.fromJson(Map<String, dynamic> json) => _FileState(
    nextIndex: json['nextIndex'] as int,
    pendingSpends: (json['pendingSpends'] as List<dynamic>)
        .map((e) => PendingSpend.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'nextIndex': nextIndex,
    'pendingSpends': pendingSpends.map((e) => e.toJson()).toList(),
  };
}
