import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/encrypted_send_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

const _recipient = 'qznt5jvuXdh4ZMnTPDnHo4Xq3KwjZPDRqwmd4AW3nDGmuEACG';

WormholeUtxo _utxo(int scaled) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: 't$scaled',
    blockHeight: 1,
    timestamp: DateTime(2026),
    fromId: 'from',
    toId: 'to',
    amount: wormholeTokenFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
    extrinsicId: '',
    viaWormhole: false,
  ),
  owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: ''),
  nullifierHex: '0xn$scaled',
);

EncryptedAccountState _state(List<WormholeUtxo> utxos, {DateTime? loadedAt}) => EncryptedAccountState(
  accountId: 'addr',
  ownAddresses: const {'addr'},
  received: utxos,
  spends: const {},
  utxos: utxos,
  pendingChangeToken: BigInt.zero,
  nextIndex: 0,
  nextChangeIndex: 0,
  loadedAt: loadedAt,
);

/// Never scans or proves: counts direct load() calls and records sends.
class _FakeEncryptedAccountService extends EncryptedAccountService {
  _FakeEncryptedAccountService() : super(walletIndex: 1, getMnemonic: () async => 'unused');

  int loads = 0;
  final sentPlans = <WormholeSpendPlan>[];

  @override
  Future<EncryptedAccountState> load({WormholeProgressCallback? onProgress, IsCancelledCallback? isCancelled}) async {
    loads++;
    return _state(const []);
  }

  @override
  Future<ClaimResult> send({
    required WormholeSpendPlan plan,
    required String recipientAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    String? rpcUrl,
  }) async {
    sentPlans.add(plan);
    return ClaimResult(
      totalWithdrawn: plan.amountToken,
      transfersProcessed: 1,
      batchesSubmitted: 1,
      txHashes: const [],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final account = makeAccount(1, accountType: AccountType.encrypted);
  final amount = wormholeTokenFromScaled(400);
  late Directory tempDir;
  late _FakeEncryptedAccountService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('enc_send_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    service = _FakeEncryptedAccountService();
  });

  tearDown(() async {
    await service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await tempDir.delete(recursive: true);
  });

  /// A container whose encrypted state comes from [snapshots] in turn: the
  /// first is what the UI already holds, later ones answer refreshes.
  ({ProviderContainer container, int Function() scans}) harness(List<EncryptedAccountState> snapshots) {
    var scans = 0;
    final container = ProviderContainer(
      overrides: [
        encryptedAccountServiceProvider.overrideWith((ref, walletIndex) => service),
        encryptedStateProvider.overrideWith((ref, walletIndex) => Future.value(snapshots[scans++])),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, scans: () => scans);
  }

  Future<EncryptedSendState> run(ProviderContainer container, WormholeSpendPlan plan) async {
    final sub = container.listen(encryptedSendControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container
        .read(encryptedSendControllerProvider.notifier)
        .start(account: account, plan: plan, amount: amount, recipientAddress: _recipient);
    return sub.read();
  }

  test('a snapshot younger than maxStateAge is trusted: no rescan before proving', () async {
    final utxos = [_utxo(1000)];
    final plan = selectWormholeInputs(utxos: utxos, amountToken: amount);
    final h = harness([_state(utxos)]);
    await h.container.read(encryptedStateProvider(account.walletIndex).future);

    final result = await run(h.container, plan);

    expect(result.phase, EncryptedSendPhase.succeeded);
    expect(service.sentPlans, [plan]);
    expect(service.loads, 0);
    expect(h.scans(), 1, reason: 'only the read the UI already made');
  });

  test('an older snapshot is refreshed through the provider before proving', () async {
    final utxos = [_utxo(1000)];
    final plan = selectWormholeInputs(utxos: utxos, amountToken: amount);
    final stale = _state(utxos, loadedAt: DateTime.now().subtract(EncryptedSendController.maxStateAge * 2));
    final h = harness([stale, _state(utxos)]);
    await h.container.read(encryptedStateProvider(account.walletIndex).future);

    final result = await run(h.container, plan);

    expect(result.phase, EncryptedSendPhase.succeeded);
    expect(service.sentPlans, [plan]);
    expect(service.loads, 0, reason: 'the refresh goes through the provider, never a side scan');
    expect(h.scans(), 2, reason: 'exactly one refresh before proving');
  });

  test('a plan whose input was spent since review is reported stale and nothing is sent', () async {
    final utxos = [_utxo(1000)];
    final plan = selectWormholeInputs(utxos: utxos, amountToken: amount);
    final h = harness([
      _state([_utxo(900)]),
    ]);
    await h.container.read(encryptedStateProvider(account.walletIndex).future);

    final result = await run(h.container, plan);

    expect(result.phase, EncryptedSendPhase.planStale);
    expect(service.sentPlans, isEmpty);
  });

  test('canSpend requires every planned input to be spendable', () {
    final utxos = [_utxo(1000), _utxo(500)];
    final plan = selectWormholeInputs(utxos: utxos, amountToken: wormholeTokenFromScaled(1200));
    expect(plan.inputCount, 2);
    expect(_state(utxos).canSpend(plan), isTrue);
    expect(_state([_utxo(1000)]).canSpend(plan), isFalse);
    expect(_state(const []).canSpend(plan), isFalse);
  });
}
