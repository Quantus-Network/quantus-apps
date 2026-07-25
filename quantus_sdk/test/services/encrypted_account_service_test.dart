import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/account_discovery_service.dart';
import 'package:quantus_sdk/src/services/encrypted_account_service.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_send_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:ss58/ss58.dart';

/// Deterministic wormhole address for HD index [index] (valid SS58 so
/// `getAccountId32` can decode it inside `send`).
String addressAt(int index) => Address(prefix: 189, pubkey: Uint8List(32)..[31] = index).encode();

String secretAt(int index) => '0x${(index + 1).toRadixString(16).padLeft(2, '0') * 32}';

WormholeUtxo _utxo(int scaled, {int index = 0, String? nullifierHex}) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: 't$scaled',
    blockHeight: 1,
    fromId: 'from',
    toId: addressAt(index),
    amount: wormholePlanckFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
  ),
  owner: WormholeAddressInfo(index: index, address: addressAt(index), secretHex: secretAt(index)),
  nullifierHex: nullifierHex ?? '0xn$scaled',
);

class _FakeHdWallet extends HdWalletService {
  @override
  WormholeKeyPair deriveWormholeKeyPair({required String mnemonic, int index = 0}) => WormholeKeyPair(
    address: addressAt(index),
    addressHex: '0x${'00' * 31}${(index).toRadixString(16).padLeft(2, '0')}',
    rewardsPreimageHex: '0x',
    secretHex: secretAt(index),
  );
}

class _FakeDiscovery extends AccountDiscoveryService {
  Set<int> used;

  _FakeDiscovery(this.used) : super(_FakeHdWallet());

  @override
  Future<Set<int>> discoverUsedIndices({required String Function(int index) addressAt, int gapLimit = 20}) async =>
      used;
}

class _FakeUtxoService extends WormholeUtxoService {
  WormholeUtxoResult result = WormholeUtxoResult(
    utxos: const [],
    totalReceivedPlanck: BigInt.zero,
    totalSpentPlanck: BigInt.zero,
  );

  /// When set, [getUnspentUtxos] blocks until the completer resolves — lets
  /// tests race a slow load() against logout.
  Completer<void>? gate;

  @override
  Future<WormholeUtxoResult> getUnspentUtxos({
    required List<WormholeAddressInfo> addresses,
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    final g = gate;
    if (g != null) await g.future;
    return result;
  }
}

/// Immediately "submits" every batch, reporting one fake nullifier per leaf.
/// When [gate] is set, submission blocks until it resolves — lets tests race
/// a slow send() against logout or another send.
class _FakeSendService extends WormholeSendService {
  final capturedBatchesList = <List<List<WormholeLeafSpend>>>[];
  Completer<void>? gate;

  List<List<WormholeLeafSpend>>? get capturedBatches => capturedBatchesList.isEmpty ? null : capturedBatchesList.last;

  @override
  Future<ClaimResult> sendSpends({
    required List<List<WormholeLeafSpend>> batches,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    Future<void> Function(int batchIndex, List<String> nullifierHexes)? onBatchSubmitted,
    String? rpcUrl,
  }) async {
    capturedBatchesList.add(batches);
    final g = gate;
    if (g != null) await g.future;
    for (var i = 0; i < batches.length; i++) {
      await onBatchSubmitted?.call(i, [for (final s in batches[i]) '0xsubmitted_${i}_${s.outputAmount1}']);
    }
    return ClaimResult(
      totalWithdrawn: BigInt.zero,
      transfersProcessed: batches.fold(0, (s, b) => s + b.length),
      batchesSubmitted: batches.length,
      txHashes: const ['0xhash'],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeDiscovery discovery;
  late _FakeUtxoService utxoService;
  late _FakeSendService sendService;
  late EncryptedAccountService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('enc_acct_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    discovery = _FakeDiscovery({});
    utxoService = _FakeUtxoService();
    sendService = _FakeSendService();
    service = EncryptedAccountService(
      walletIndex: 0,
      getMnemonic: () async => 'test mnemonic',
      hdWalletService: _FakeHdWallet(),
      utxoService: utxoService,
      discoveryService: discovery,
      sendService: sendService,
    );
  });

  tearDown(() async {
    // Keep the static live-instance registry clean between tests.
    await service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await tempDir.delete(recursive: true);
  });

  Future<void> seedState({required int nextIndex, List<PendingSpend> pendingSpends = const []}) async {
    final file = File('${tempDir.path}/encrypted_account_w0.json');
    await file.writeAsString(
      jsonEncode({'nextIndex': nextIndex, 'pendingSpends': pendingSpends.map((e) => e.toJson()).toList()}),
    );
  }

  Future<Map<String, dynamic>> readStateFile() async =>
      jsonDecode(await File('${tempDir.path}/encrypted_account_w0.json').readAsString()) as Map<String, dynamic>;

  group('load reconciliation', () {
    test('bumps nextIndex to one past the highest discovered index', () async {
      discovery.used = {0, 1, 2};
      final state = await service.load();
      expect(state.nextIndex, 3);
      expect((await readStateFile())['nextIndex'], 3);
    });

    test('keeps a persisted nextIndex that is ahead of discovery', () async {
      await seedState(nextIndex: 5);
      discovery.used = {0, 1};
      final state = await service.load();
      expect(state.nextIndex, 5);
    });

    test('prunes a pending spend once nullifiers are spent and change arrived', () async {
      discovery.used = {0, 1};
      utxoService.result = WormholeUtxoResult(
        utxos: [_utxo(500, nullifierHex: '0xc')],
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        totalSpentPlanck: BigInt.zero,
      );
      await seedState(
        nextIndex: 2,
        pendingSpends: [
          PendingSpend(
            // '0xa' is absent from the unspent set (spent on-chain) and the
            // change address (index 1) is discovered: fully confirmed.
            nullifiers: ['0xa'],
            changeAddress: addressAt(1),
            changeAmountPlanck: wormholePlanckFromScaled(100),
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );

      final state = await service.load();
      expect(state.pendingChangePlanck, BigInt.zero);
      expect(state.utxos.map((u) => u.nullifierHex), ['0xc']);
      expect((await readStateFile())['pendingSpends'], isEmpty);
    });

    test('keeps an unconfirmed pending spend, hides its inputs and counts its change', () async {
      discovery.used = {0};
      final pendingChange = wormholePlanckFromScaled(70);
      utxoService.result = WormholeUtxoResult(
        // '0xb' is still reported unspent by the indexer (the spend hasn't
        // been indexed yet) so the record must be kept and '0xb' hidden.
        utxos: [
          _utxo(300, nullifierHex: '0xb'),
          _utxo(500, nullifierHex: '0xc'),
        ],
        totalReceivedPlanck: wormholePlanckFromScaled(800),
        totalSpentPlanck: BigInt.zero,
      );
      await seedState(
        nextIndex: 1,
        pendingSpends: [
          PendingSpend(
            nullifiers: ['0xb'],
            changeAddress: addressAt(1),
            changeAmountPlanck: pendingChange,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
      );

      final state = await service.load();
      expect(state.utxos.map((u) => u.nullifierHex), ['0xc']);
      expect(state.pendingChangePlanck, pendingChange);
      expect(state.balance, wormholePlanckFromScaled(500) + pendingChange);
      expect(((await readStateFile())['pendingSpends'] as List).length, 1);
    });

    test('drops an expired pending spend even when unconfirmed', () async {
      discovery.used = {0};
      utxoService.result = WormholeUtxoResult(
        utxos: [_utxo(300, nullifierHex: '0xb')],
        totalReceivedPlanck: wormholePlanckFromScaled(300),
        totalSpentPlanck: BigInt.zero,
      );
      await seedState(
        nextIndex: 1,
        pendingSpends: [
          PendingSpend(
            nullifiers: ['0xb'],
            changeAddress: addressAt(1),
            changeAmountPlanck: wormholePlanckFromScaled(10),
            createdAtMs: DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
          ),
        ],
      );

      final state = await service.load();
      // Record dropped: input spendable again, change no longer counted.
      expect(state.utxos.map((u) => u.nullifierHex), ['0xb']);
      expect(state.pendingChangePlanck, BigInt.zero);
      expect((await readStateFile())['pendingSpends'], isEmpty);
    });
  });

  group('send bookkeeping', () {
    final recipient = Address(prefix: 189, pubkey: Uint8List.fromList(List.filled(32, 0x22))).encode();

    test('records nullifiers and change, and bumps nextIndex, per submitted batch', () async {
      await seedState(nextIndex: 1);
      final plan = selectWormholeInputs(utxos: [_utxo(1000)], amountPlanck: wormholePlanckFromScaled(400));
      expect(plan.changePlanck, greaterThan(BigInt.zero));

      await service.send(plan: plan, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {});

      final json = await readStateFile();
      expect(json['nextIndex'], 2);
      final pending = (json['pendingSpends'] as List).cast<Map<String, dynamic>>();
      expect(pending.length, 1);
      expect(pending[0]['nullifiers'], ['0xsubmitted_0_400']);
      expect(pending[0]['changeAddress'], addressAt(1));
      expect(BigInt.parse(pending[0]['changeAmountPlanck'] as String), plan.changePlanck);

      // Leaf spend wiring: full net split between recipient and change address.
      final spend = sendService.capturedBatches![0][0];
      expect(spend.exitAccount1, Address.decode(recipient).pubkey);
      expect(spend.outputAmount1, 400);
      expect(spend.exitAccount2, Address.decode(addressAt(1)).pubkey);
      expect(spend.outputAmount2, wormholeScaledFromPlanck(plan.changePlanck));
    });

    test('does not allocate a change address for an exact-max send', () async {
      await seedState(nextIndex: 1);
      final utxos = [_utxo(1000)];
      final plan = selectWormholeInputs(utxos: utxos, amountPlanck: wormholeMaxSendable(utxos));
      expect(plan.changePlanck, BigInt.zero);

      await service.send(plan: plan, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {});

      final json = await readStateFile();
      expect(json['nextIndex'], 1);
      final pending = (json['pendingSpends'] as List).cast<Map<String, dynamic>>();
      expect(pending.length, 1);
      expect(pending[0]['changeAddress'], isNull);
      expect(BigInt.parse(pending[0]['changeAmountPlanck'] as String), BigInt.zero);
      expect(sendService.capturedBatches![0][0].exitAccount2, isNull);
    });
  });

  group('logout / dispose races', () {
    final recipient = Address(prefix: 189, pubkey: Uint8List.fromList(List.filled(32, 0x22))).encode();
    File stateFile() => File('${tempDir.path}/encrypted_account_w0.json');

    test('a batch submitted after logout cannot recreate cleared state', () async {
      await seedState(nextIndex: 1);
      final plan = selectWormholeInputs(utxos: [_utxo(1000)], amountPlanck: wormholePlanckFromScaled(400));
      sendService.gate = Completer<void>();
      final sendFuture = service.send(
        plan: plan,
        recipientAddress: recipient,
        circuitBinsDir: '/unused',
        onProgress: (_) {},
      );
      await Future<void>.delayed(Duration.zero); // let the send reach the gate

      // Logout: quiesces every live instance, then wipes the state files.
      await EncryptedAccountService.clearAllPersistedState();
      expect(stateFile().existsSync(), isFalse);

      // The delayed batch submission now completes — its persistence callback
      // must fail on the disposed gate instead of resurrecting the file.
      sendService.gate!.complete();
      await expectLater(sendFuture, throwsA(isA<StateError>()));
      expect(stateFile().existsSync(), isFalse);
    });

    test('a load finishing after dispose cannot write state', () async {
      discovery.used = {0, 1};
      utxoService.gate = Completer<void>();
      final loadFuture = service.load();
      await Future<void>.delayed(Duration.zero); // let the load reach the gate

      await service.dispose();
      utxoService.gate!.complete();
      await expectLater(loadFuture, throwsA(isA<StateError>()));
      expect(stateFile().existsSync(), isFalse);
    });

    test('load and send refuse to start after dispose', () async {
      await seedState(nextIndex: 1);
      final plan = selectWormholeInputs(utxos: [_utxo(1000)], amountPlanck: wormholePlanckFromScaled(400));
      await service.dispose();
      await expectLater(service.load(), throwsA(isA<StateError>()));
      await expectLater(
        service.send(plan: plan, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {}),
        throwsA(isA<StateError>()),
      );
    });

    test('two overlapping sends allocate distinct change indices', () async {
      await seedState(nextIndex: 1);
      final plan1 = selectWormholeInputs(utxos: [_utxo(1000)], amountPlanck: wormholePlanckFromScaled(400));
      final plan2 = selectWormholeInputs(utxos: [_utxo(900)], amountPlanck: wormholePlanckFromScaled(300));
      expect(plan1.changePlanck, greaterThan(BigInt.zero));
      expect(plan2.changePlanck, greaterThan(BigInt.zero));

      sendService.gate = Completer<void>();
      final f1 = service.send(plan: plan1, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {});
      final f2 = service.send(plan: plan2, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {});
      await Future<void>.delayed(Duration.zero);
      sendService.gate!.complete();
      await Future.wait([f1, f2]);

      expect(sendService.capturedBatchesList.length, 2);
      final change1 = sendService.capturedBatchesList[0][0][0].exitAccount2;
      final change2 = sendService.capturedBatchesList[1][0][0].exitAccount2;
      expect(change1, Address.decode(addressAt(1)).pubkey);
      expect(change2, Address.decode(addressAt(2)).pubkey);
    });
  });

  group('ownsAddress', () {
    test('recognizes every derived index up to and including nextIndex', () async {
      await seedState(nextIndex: 2);
      expect(await service.ownsAddress(addressAt(0)), isTrue);
      expect(await service.ownsAddress(addressAt(1)), isTrue);
      expect(await service.ownsAddress(addressAt(2)), isTrue);
      expect(await service.ownsAddress(addressAt(9)), isFalse);
      final other = Address(prefix: 189, pubkey: Uint8List.fromList(List.filled(32, 0x33))).encode();
      expect(await service.ownsAddress(other), isFalse);
    });
  });

  group('PendingSpend', () {
    test('round-trips through JSON', () {
      final original = PendingSpend(
        nullifiers: ['0xabc', '0xdef'],
        changeAddress: 'addr_3',
        changeAmountPlanck: BigInt.from(123456),
        createdAtMs: 1700000000000,
      );
      final json = original.toJson();
      final restored = PendingSpend.fromJson(json);

      expect(restored.nullifiers, original.nullifiers);
      expect(restored.changeAddress, original.changeAddress);
      expect(restored.changeAmountPlanck, original.changeAmountPlanck);
      expect(restored.createdAtMs, original.createdAtMs);
    });

    test('round-trips with null changeAddress', () {
      final original = PendingSpend(
        nullifiers: ['0x01'],
        changeAddress: null,
        changeAmountPlanck: BigInt.zero,
        createdAtMs: 1700000000000,
      );
      final json = original.toJson();
      final restored = PendingSpend.fromJson(json);

      expect(restored.changeAddress, isNull);
      expect(restored.changeAmountPlanck, BigInt.zero);
    });
  });

  group('EncryptedAccountState', () {
    test('balance includes pending change', () {
      final state = EncryptedAccountState(
        utxos: [_utxo(100), _utxo(200)],
        pendingChangePlanck: wormholePlanckFromScaled(50),
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        totalSpentPlanck: wormholePlanckFromScaled(150),
        nextIndex: 2,
      );
      final utxoSum = wormholePlanckFromScaled(100) + wormholePlanckFromScaled(200);
      expect(state.balance, utxoSum + wormholePlanckFromScaled(50));
    });

    test('maxSendable excludes pending change', () {
      final utxos = [_utxo(100), _utxo(200)];
      final state = EncryptedAccountState(
        utxos: utxos,
        pendingChangePlanck: wormholePlanckFromScaled(50),
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        totalSpentPlanck: wormholePlanckFromScaled(150),
        nextIndex: 2,
      );
      expect(state.maxSendable, wormholeMaxSendable(utxos));
    });

    test('totalReceivedPlanck and totalSpentPlanck are stored', () {
      final received = wormholePlanckFromScaled(1000);
      final spent = wormholePlanckFromScaled(300);
      final state = EncryptedAccountState(
        utxos: [],
        pendingChangePlanck: BigInt.zero,
        totalReceivedPlanck: received,
        totalSpentPlanck: spent,
        nextIndex: 5,
      );
      expect(state.totalReceivedPlanck, received);
      expect(state.totalSpentPlanck, spent);
    });
  });

  group('WormholeUtxoResult', () {
    test('carries totals alongside utxos', () {
      final utxos = [_utxo(100), _utxo(200)];
      final result = WormholeUtxoResult(
        utxos: utxos,
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        totalSpentPlanck: wormholePlanckFromScaled(200),
      );
      expect(result.utxos.length, 2);
      expect(result.totalReceivedPlanck, wormholePlanckFromScaled(500));
      expect(result.totalSpentPlanck, wormholePlanckFromScaled(200));
    });
  });
}
