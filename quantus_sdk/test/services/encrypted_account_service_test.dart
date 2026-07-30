import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart' show hex;
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

/// Change-branch counterpart of [addressAt], distinct at every index.
String changeAddressAt(int index) {
  final pubkey = Uint8List(32)
    ..[30] = 1
    ..[31] = index;
  return Address(prefix: 189, pubkey: pubkey).encode();
}

String secretAt(int index) => '0x${(index + 1).toRadixString(16).padLeft(2, '0') * 32}';

String changeSecretAt(int index) => '0x${(index + 0x81).toRadixString(16).padLeft(2, '0') * 32}';

WormholeUtxo _utxo(int scaled, {int index = 0, bool isChange = false, String? nullifierHex}) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: 't$scaled',
    blockHeight: 1,
    fromId: 'from',
    toId: isChange ? changeAddressAt(index) : addressAt(index),
    amount: wormholePlanckFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
  ),
  // secretHex blank like production getUnspentUtxos (M11): spenders re-derive.
  owner: WormholeAddressInfo(
    index: index,
    isChange: isChange,
    address: isChange ? changeAddressAt(index) : addressAt(index),
    secretHex: '',
  ),
  nullifierHex: nullifierHex ?? '0xn$scaled',
);

class _FakeHdWallet extends HdWalletService {
  /// Counts derivations so tests can assert key pairs are re-derived on
  /// demand instead of served from a session cache (M11).
  int derivations = 0;

  @override
  WormholeKeyPair deriveWormholeKeyPair({required String mnemonic, int index = 0}) {
    derivations++;
    return WormholeKeyPair(
      address: addressAt(index),
      addressHex: '0x${'00' * 31}${(index).toRadixString(16).padLeft(2, '0')}',
      rewardsPreimageHex: '0x',
      secretHex: secretAt(index),
    );
  }

  @override
  WormholeKeyPair deriveWormholeChangeAddressKeyPair({required String mnemonic, int index = 0}) {
    derivations++;
    return WormholeKeyPair(
      address: changeAddressAt(index),
      addressHex: '0x${'00' * 30}01${(index).toRadixString(16).padLeft(2, '0')}',
      rewardsPreimageHex: '0x',
      secretHex: changeSecretAt(index),
    );
  }
}

class _FakeDiscovery extends AccountDiscoveryService {
  Set<int> used;
  Set<int> usedChange = const {};

  _FakeDiscovery(this.used) : super(_FakeHdWallet());

  @override
  Future<Set<int>> discoverUsedIndices({required String Function(int index) addressAt, int gapLimit = 20}) async =>
      addressAt(0) == changeAddressAt(0) ? usedChange : used;
}

class _FakeUtxoService extends WormholeUtxoService {
  WormholeUtxoResult result = WormholeUtxoResult(
    utxos: const [],
    totalReceivedPlanck: BigInt.zero,
    changeReceivedPlanck: BigInt.zero,
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
/// a slow send() against logout or another send. When [error] is set,
/// submission throws it — lets tests exercise the failure path of send().
class _FakeSendService extends WormholeSendService {
  final capturedBatchesList = <List<List<WormholeLeafSpend>>>[];

  /// Copies of each leaf's secret taken at submission time — the live buffers
  /// are zeroized by EncryptedAccountService.send once the send finishes.
  final capturedSecretCopies = <Uint8List>[];
  Completer<void>? gate;
  Object? error;

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
    for (final batch in batches) {
      for (final spend in batch) {
        capturedSecretCopies.add(Uint8List.fromList(spend.secret));
      }
    }
    final g = gate;
    if (g != null) await g.future;
    final err = error;
    if (err != null) throw err;
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
  late _FakeHdWallet hdWallet;
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
    hdWallet = _FakeHdWallet();
    discovery = _FakeDiscovery({});
    utxoService = _FakeUtxoService();
    sendService = _FakeSendService();
    service = EncryptedAccountService(
      walletIndex: 0,
      getMnemonic: () async => 'test mnemonic',
      hdWalletService: hdWallet,
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

  Future<void> seedState({
    required int nextIndex,
    int? nextChangeIndex,
    List<PendingSpend> pendingSpends = const [],
  }) async {
    final file = File('${tempDir.path}/encrypted_account_w0.json');
    await file.writeAsString(
      jsonEncode({
        'nextIndex': nextIndex,
        'nextChangeIndex': ?nextChangeIndex,
        'pendingSpends': pendingSpends.map((e) => e.toJson()).toList(),
      }),
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

    test('bumps nextChangeIndex to one past the highest discovered change index', () async {
      discovery.used = {0};
      discovery.usedChange = {0, 1};
      final state = await service.load();
      expect(state.nextIndex, 1);
      expect(state.nextChangeIndex, 2);
      expect((await readStateFile())['nextChangeIndex'], 2);
    });

    test('keeps a persisted nextIndex that is ahead of discovery', () async {
      await seedState(nextIndex: 5, nextChangeIndex: 3);
      discovery.used = {0, 1};
      discovery.usedChange = {0};
      final state = await service.load();
      expect(state.nextIndex, 5);
      expect(state.nextChangeIndex, 3);
    });

    test('a legacy state file without nextChangeIndex loads with change index 0', () async {
      await seedState(nextIndex: 4);
      final state = await service.load();
      expect(state.nextIndex, 4);
      expect(state.nextChangeIndex, 0);
    });

    test('prunes a pending spend once nullifiers are spent and change arrived', () async {
      discovery.used = {0};
      discovery.usedChange = {0};
      utxoService.result = WormholeUtxoResult(
        utxos: [_utxo(500, nullifierHex: '0xc')],
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        changeReceivedPlanck: BigInt.zero,
        totalSpentPlanck: BigInt.zero,
      );
      await seedState(
        nextIndex: 1,
        nextChangeIndex: 1,
        pendingSpends: [
          PendingSpend(
            // '0xa' is absent from the unspent set (spent on-chain) and the
            // change address (change index 0) is discovered: fully confirmed.
            nullifiers: ['0xa'],
            changeAddress: changeAddressAt(0),
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
        changeReceivedPlanck: BigInt.zero,
        totalSpentPlanck: BigInt.zero,
      );
      await seedState(
        nextIndex: 1,
        pendingSpends: [
          PendingSpend(
            nullifiers: ['0xb'],
            changeAddress: changeAddressAt(0),
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
        changeReceivedPlanck: BigInt.zero,
        totalSpentPlanck: BigInt.zero,
      );
      await seedState(
        nextIndex: 1,
        pendingSpends: [
          PendingSpend(
            nullifiers: ['0xb'],
            changeAddress: changeAddressAt(0),
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

    test('records nullifiers and change, and bumps nextChangeIndex, per submitted batch', () async {
      await seedState(nextIndex: 1);
      final plan = selectWormholeInputs(utxos: [_utxo(1000)], amountPlanck: wormholePlanckFromScaled(400));
      expect(plan.changePlanck, greaterThan(BigInt.zero));

      await service.send(plan: plan, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {});

      final json = await readStateFile();
      // The receive sequence is untouched; change consumed change index 0.
      expect(json['nextIndex'], 1);
      expect(json['nextChangeIndex'], 1);
      final pending = (json['pendingSpends'] as List).cast<Map<String, dynamic>>();
      expect(pending.length, 1);
      expect(pending[0]['nullifiers'], ['0xsubmitted_0_400']);
      expect(pending[0]['changeAddress'], changeAddressAt(0));
      expect(BigInt.parse(pending[0]['changeAmountPlanck'] as String), plan.changePlanck);

      // Leaf spend wiring: full net split between recipient and change address.
      final spend = sendService.capturedBatches![0][0];
      expect(spend.exitAccount1, Address.decode(recipient).pubkey);
      expect(spend.outputAmount1, 400);
      expect(spend.exitAccount2, Address.decode(changeAddressAt(0)).pubkey);
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
      expect(json['nextChangeIndex'], 0);
      final pending = (json['pendingSpends'] as List).cast<Map<String, dynamic>>();
      expect(pending.length, 1);
      expect(pending[0]['changeAddress'], isNull);
      expect(BigInt.parse(pending[0]['changeAmountPlanck'] as String), BigInt.zero);
      expect(sendService.capturedBatches![0][0].exitAccount2, isNull);
    });
  });

  group('secret hygiene (M11)', () {
    final recipient = Address(prefix: 189, pubkey: Uint8List.fromList(List.filled(32, 0x22))).encode();

    test('key pairs are re-derived on every call, never cached', () async {
      await seedState(nextIndex: 2);
      final before = hdWallet.derivations;
      await service.keyPairAt(0);
      await service.keyPairAt(0);
      await service.receiveKeyPair();
      expect(hdWallet.derivations, before + 3);
    });

    test('send re-derives input secrets from the owner index and zeroizes them afterwards', () async {
      await seedState(nextIndex: 1);
      final plan = selectWormholeInputs(utxos: [_utxo(1000)], amountPlanck: wormholePlanckFromScaled(400));

      await service.send(plan: plan, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {});

      // The prover received the correct secret for the UTXO's owner index…
      expect(sendService.capturedSecretCopies.single, hex.decode(secretAt(0).replaceFirst('0x', '')));
      // …and the live buffer was zeroized once the send completed.
      final liveSecret = sendService.capturedBatches![0][0].secret;
      expect(liveSecret.every((b) => b == 0), isTrue);
    });

    test('send re-derives change-branch secrets for change-owned inputs', () async {
      await seedState(nextIndex: 1);
      final plan = selectWormholeInputs(
        utxos: [_utxo(1000, isChange: true)],
        amountPlanck: wormholePlanckFromScaled(400),
      );

      await service.send(plan: plan, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {});

      expect(sendService.capturedSecretCopies.single, hex.decode(changeSecretAt(0).replaceFirst('0x', '')));
    });

    test('send zeroizes secrets even when the send fails', () async {
      await seedState(nextIndex: 1);
      final plan = selectWormholeInputs(utxos: [_utxo(1000)], amountPlanck: wormholePlanckFromScaled(400));
      sendService.error = StateError('boom');

      await expectLater(
        service.send(plan: plan, recipientAddress: recipient, circuitBinsDir: '/unused', onProgress: (_) {}),
        throwsA(isA<StateError>()),
      );
      final liveSecret = sendService.capturedBatches![0][0].secret;
      expect(liveSecret.every((b) => b == 0), isTrue);
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
      expect(change1, Address.decode(changeAddressAt(0)).pubkey);
      expect(change2, Address.decode(changeAddressAt(1)).pubkey);
    });
  });

  group('ownsAddress', () {
    test('recognizes both branches up to and including their next indices', () async {
      await seedState(nextIndex: 2, nextChangeIndex: 1);
      expect(await service.ownsAddress(addressAt(0)), isTrue);
      expect(await service.ownsAddress(addressAt(1)), isTrue);
      expect(await service.ownsAddress(addressAt(2)), isTrue);
      expect(await service.ownsAddress(addressAt(9)), isFalse);
      expect(await service.ownsAddress(changeAddressAt(0)), isTrue);
      expect(await service.ownsAddress(changeAddressAt(1)), isTrue);
      expect(await service.ownsAddress(changeAddressAt(9)), isFalse);
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
    EncryptedAccountState stateWith({
      List<WormholeUtxo> utxos = const [],
      BigInt? pendingChangePlanck,
      BigInt? totalReceivedPlanck,
      BigInt? changeReceivedPlanck,
      BigInt? totalSpentPlanck,
    }) => EncryptedAccountState(
      utxos: utxos,
      pendingChangePlanck: pendingChangePlanck ?? BigInt.zero,
      totalReceivedPlanck: totalReceivedPlanck ?? BigInt.zero,
      changeReceivedPlanck: changeReceivedPlanck ?? BigInt.zero,
      totalSpentPlanck: totalSpentPlanck ?? BigInt.zero,
      nextIndex: 2,
      nextChangeIndex: 1,
    );

    test('balance includes pending change', () {
      final state = stateWith(utxos: [_utxo(100), _utxo(200)], pendingChangePlanck: wormholePlanckFromScaled(50));
      final utxoSum = wormholePlanckFromScaled(100) + wormholePlanckFromScaled(200);
      expect(state.balance, utxoSum + wormholePlanckFromScaled(50));
    });

    test('maxSendable excludes pending change', () {
      final utxos = [_utxo(100), _utxo(200)];
      final state = stateWith(utxos: utxos, pendingChangePlanck: wormholePlanckFromScaled(50));
      expect(state.maxSendable, wormholeMaxSendable(utxos));
    });

    test('incomingPlanck excludes change received and balances against spent', () {
      // Received 1000 externally + 300 as returning change, 400 nullified:
      // the indexed balance identity is incoming + change - spent.
      final state = stateWith(
        utxos: [_utxo(900)],
        totalReceivedPlanck: wormholePlanckFromScaled(1300),
        changeReceivedPlanck: wormholePlanckFromScaled(300),
        totalSpentPlanck: wormholePlanckFromScaled(400),
      );
      expect(state.incomingPlanck, wormholePlanckFromScaled(1000));
      expect(state.incomingPlanck + state.changeReceivedPlanck - state.totalSpentPlanck, state.balance);
    });
  });

  group('WormholeUtxoResult', () {
    test('carries totals alongside utxos', () {
      final utxos = [_utxo(100), _utxo(200)];
      final result = WormholeUtxoResult(
        utxos: utxos,
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        changeReceivedPlanck: wormholePlanckFromScaled(120),
        totalSpentPlanck: wormholePlanckFromScaled(200),
      );
      expect(result.utxos.length, 2);
      expect(result.totalReceivedPlanck, wormholePlanckFromScaled(500));
      expect(result.changeReceivedPlanck, wormholePlanckFromScaled(120));
      expect(result.totalSpentPlanck, wormholePlanckFromScaled(200));
    });
  });
}
