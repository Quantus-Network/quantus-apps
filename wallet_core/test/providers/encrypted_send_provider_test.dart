import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/wallet_session.dart';

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

/// Never scans or proves. Like the real service, its send has a stretch
/// before the operation exists ([startup]), asks [isCancelled] at the end of
/// it, and its cancel only reaches an operation that exists.
class _FakeEncryptedAccountService extends EncryptedAccountService {
  _FakeEncryptedAccountService() : super(walletIndex: 0, getMnemonic: () async => 'unused');

  /// The plans whose operation started.
  final sentPlans = <WormholeSpendPlan>[];
  int cancels = 0;

  /// Holds a send back before its operation exists.
  Completer<void>? startup;

  /// Completes when a send has reached [startup].
  final reachedStartup = Completer<void>();

  /// When set, the operation runs until it is cancelled; otherwise it
  /// succeeds at once.
  bool runsUntilCancelled = false;
  Completer<void>? _operation;

  /// Completes when an operation has started.
  final started = Completer<void>();

  /// What the operation reports once it ends: the hash of each transaction it
  /// handed to the chain, and whether a cancel stopped it after some of them.
  List<String> txHashes = const [];
  bool endsCancelled = false;

  @override
  Future<ClaimResult> send({
    required WormholeSpendPlan plan,
    required String recipientAddress,
    required String circuitBinsDir,
    required ClaimProgressCallback onProgress,
    String? rpcUrl,
    IsCancelledCallback? isCancelled,
  }) async {
    if (!reachedStartup.isCompleted) reachedStartup.complete();
    await startup?.future;
    if (isCancelled?.call() ?? false) throw const ClaimCancelled();

    sentPlans.add(plan);
    if (!started.isCompleted) started.complete();
    if (runsUntilCancelled) {
      await (_operation = Completer<void>()).future;
      throw const ClaimCancelled();
    }
    return ClaimResult(
      totalWithdrawn: plan.amountToken,
      transfersProcessed: 1,
      batchesSubmitted: 1,
      txHashes: txHashes,
      cancelled: endsCancelled,
    );
  }

  @override
  Future<void> cancel() async {
    cancels++;
    final operation = _operation;
    if (operation != null && !operation.isCompleted) operation.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final account = makeAccount(1, accountType: AccountType.encrypted);
  final amount = wormholeTokenFromScaled(400);
  final utxos = [_utxo(1000)];
  final plan = selectWormholeInputs(utxos: utxos, amountToken: amount);
  late Directory tempDir;
  late _FakeEncryptedAccountService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('enc_send_cancel_test');
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
  Future<ProviderContainer> containerWith(List<Future<EncryptedAccountState>> snapshots) async {
    var scans = 0;
    final container = ProviderContainer(
      overrides: [
        encryptedAccountServiceProvider.overrideWith((ref, walletIndex) => service),
        encryptedStateProvider.overrideWith((ref, walletIndex) => snapshots[scans++]),
      ],
    );
    addTearDown(container.dispose);
    await container.read(encryptedStateProvider(account.walletIndex).future);
    return container;
  }

  /// A snapshot too old to be trusted, so the send rescans before it proves.
  EncryptedAccountState oldSnapshot() =>
      _state(utxos, loadedAt: DateTime.now().subtract(EncryptedSendController.maxStateAge * 2));

  Future<void> start(ProviderContainer container) => container
      .read(encryptedSendControllerProvider.notifier)
      .start(account: account, plan: plan, amount: amount, recipientAddress: _recipient);

  Future<void> cancel(ProviderContainer container) => container.read(encryptedSendControllerProvider.notifier).cancel();

  group('the recipient among the recent addresses', () {
    Future<(ProviderSubscription<EncryptedSendState>, Future<void>, ProviderContainer)> sendHeldAtStartup() async {
      service.startup = Completer<void>();
      final fresh = _state(utxos, loadedAt: DateTime.now());
      final container = await containerWith([Future.value(fresh), Future.value(fresh)]);
      final send = container.listen(encryptedSendControllerProvider, (_, _) {});
      final finished = start(container);
      await service.reachedStartup.future;
      return (send, finished, container);
    }

    test('a send finishing after a wallet reset does not save it', () async {
      final (send, finished, container) = await sendHeldAtStartup();

      container.read(walletSessionProvider).finishReset();
      service.startup!.complete();
      await finished;
      await pumpEventQueue();

      expect(send.read().phase, EncryptedSendPhase.succeeded);
      expect(await RecentAddressesService().getAddresses(), isEmpty);
    });

    test('a send finishing with no reset saves it', () async {
      final (send, finished, _) = await sendHeldAtStartup();

      service.startup!.complete();
      await finished;
      await pumpEventQueue();

      expect(send.read().phase, EncryptedSendPhase.succeeded);
      expect(await RecentAddressesService().getAddresses(), [_recipient]);
    });
  });

  test('a cancel during the scan before the send starts no send', () async {
    final refresh = Completer<EncryptedAccountState>();
    final container = await containerWith([Future.value(oldSnapshot()), refresh.future]);
    final send = container.listen(encryptedSendControllerProvider, (_, _) {});

    final finished = start(container);
    await pumpEventQueue();
    expect(send.read().phase, EncryptedSendPhase.running);

    await cancel(container);
    expect(send.read().phase, EncryptedSendPhase.canceling);

    refresh.complete(_state(utxos));
    await finished;

    expect(service.sentPlans, isEmpty);
    expect(send.read().phase, EncryptedSendPhase.cancelled);
    expect(send.read().submittedRecipientToken, BigInt.zero);
  });

  test('a cancel during the scan ends as cancelled even when the plan turned stale meanwhile', () async {
    final refresh = Completer<EncryptedAccountState>();
    final container = await containerWith([Future.value(oldSnapshot()), refresh.future]);
    final send = container.listen(encryptedSendControllerProvider, (_, _) {});

    final finished = start(container);
    await pumpEventQueue();
    await cancel(container);
    refresh.complete(_state([_utxo(900)]));
    await finished;

    expect(service.sentPlans, isEmpty);
    expect(send.read().phase, EncryptedSendPhase.cancelled);
  });

  test('a cancel while the service gets ready reaches the service, which starts no operation', () async {
    final container = await containerWith([Future.value(_state(utxos))]);
    final send = container.listen(encryptedSendControllerProvider, (_, _) {});
    final startup = service.startup = Completer<void>();

    final finished = start(container);
    await service.reachedStartup.future;
    await cancel(container);
    expect(send.read().phase, EncryptedSendPhase.canceling);

    startup.complete();
    await finished;

    expect(service.sentPlans, isEmpty);
    expect(send.read().phase, EncryptedSendPhase.cancelled);
  });

  test('a controller disposed during the scan starts no send', () async {
    final refresh = Completer<EncryptedAccountState>();
    final container = await containerWith([Future.value(oldSnapshot()), refresh.future]);
    final send = container.listen(encryptedSendControllerProvider, (_, _) {});

    final finished = start(container);
    await pumpEventQueue();
    send.close();
    await container.pump();
    expect(service.cancels, 1, reason: 'the controller was disposed');

    refresh.complete(_state(utxos));
    await finished;

    expect(service.sentPlans, isEmpty);
  });

  test('a finished send keeps the hash of every transaction it submitted', () async {
    final container = await containerWith([Future.value(_state(utxos))]);
    final send = container.listen(encryptedSendControllerProvider, (_, _) {});
    service.txHashes = const ['0xfirst', '0xsecond'];

    expect(send.read().txHashes, isEmpty);
    await start(container);

    expect(send.read().phase, EncryptedSendPhase.succeeded);
    expect(send.read().txHashes, ['0xfirst', '0xsecond']);
  });

  test('a send cancelled after some transactions keeps the hashes of those', () async {
    final container = await containerWith([Future.value(_state(utxos))]);
    final send = container.listen(encryptedSendControllerProvider, (_, _) {});
    service
      ..txHashes = const ['0xfirst']
      ..endsCancelled = true;

    await start(container);

    expect(send.read().phase, EncryptedSendPhase.cancelled);
    expect(send.read().txHashes, ['0xfirst']);
  });

  test('a cancel once the operation exists goes to the service, and the phase follows the operation', () async {
    final container = await containerWith([Future.value(_state(utxos))]);
    final send = container.listen(encryptedSendControllerProvider, (_, _) {});
    service.runsUntilCancelled = true;

    final finished = start(container);
    await service.started.future;
    expect(send.read().phase, EncryptedSendPhase.running);

    await cancel(container);
    await finished;

    expect(service.cancels, 1);
    expect(service.sentPlans, [plan]);
    expect(send.read().phase, EncryptedSendPhase.cancelled);
  });
}
