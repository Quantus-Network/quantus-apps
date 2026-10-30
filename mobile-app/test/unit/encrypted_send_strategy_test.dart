import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/one_click_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

const _depositAddress = 'qznt5jvuXdh4ZMnTPDnHo4Xq3KwjZPDRqwmd4AW3nDGmuEACG';
final _config = RemoteConfigModel.fromJson(const {});

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
  owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: '0x00'),
  nullifierHex: '0xn$scaled',
);

EncryptedAccountState _state(List<WormholeUtxo> utxos) => EncryptedAccountState(
  accountId: 'addr',
  ownAddresses: const {'addr'},
  received: utxos,
  spends: const {},
  utxos: utxos,
  pendingChangeToken: BigInt.zero,
  nextIndex: 0,
  nextChangeIndex: 0,
);

void main() {
  final account = makeAccount(1, accountType: AccountType.encrypted);
  final tenTokens = wormholeTokenFromScaled(1000);

  test('fee is the plan over the current UTXO set and survives a background rescan', () async {
    var loads = 0;
    final rescan = Completer<EncryptedAccountState>();
    final container = ProviderContainer(
      overrides: [
        encryptedStateProvider.overrideWith(
          (ref, walletIndex) =>
              ++loads == 1 ? Future.value(_state([_utxo(110), _utxo(580), _utxo(400)])) : rescan.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final strategy = EncryptedSendStrategy(account: account);
    final sub = container.listen(strategy.feeProvider(recipient: 'qz', amount: tenTokens), (_, _) {});

    expect(sub.read().pending, isTrue);
    await container.read(encryptedStateProvider(account.walletIndex).future);
    expect((sub.read().fee as EncryptedFee).plan?.feeToken, wormholeTokenFromScaled(1));
    expect(sub.read().settled, isTrue);

    container.invalidate(encryptedStateProvider(account.walletIndex));
    expect(sub.read().fee?.displayFee, wormholeTokenFromScaled(1));
    expect(loads, 2);
  });

  test('blocks unquantized and unaffordable amounts without a plan', () {
    final utxos = [_utxo(100)];
    expect(planEncryptedFee(utxos, tenTokens + BigInt.one).blocker, EncryptedSendBlocker.notQuantized);
    expect(planEncryptedFee(utxos, tenTokens).blocker, EncryptedSendBlocker.insufficient);
    expect(planEncryptedFee(utxos, BigInt.zero).plan, isNull);
  });

  group('submit refuses several inputs to a deposit address 1Click has confirmed', () {
    final lookedUp = <String>[];
    var oneClickDown = false;

    setUp(() async {
      lookedUp.clear();
      oneClickDown = false;
      SharedPreferences.setMockInitialValues({});
      await SettingsService().initialize();
    });

    Future<WidgetRef> pumpStrategyRef(WidgetTester tester) => pumpRef(
      tester,
      overrides: [
        remoteConfigProvider.overrideWith(
          (ref) => RemoteConfigNotifier(FakeRemoteConfigService(_config, remote: _config)),
        ),
        oneClickServiceProvider.overrideWithValue(
          OneClickService(
            client: MockClient((request) async {
              lookedUp.add(request.url.queryParameters['depositAddress']!);
              if (oneClickDown) throw http.ClientException('connection refused');
              return http.Response(
                jsonEncode({
                  'items': [
                    {'depositAddress': _depositAddress},
                  ],
                }),
                200,
              );
            }),
          ),
        ),
      ],
    );

    WormholeSpendPlan plan(int inputs) => WormholeSpendPlan(
      batches: [
        [
          for (var i = 1; i <= inputs; i++)
            WormholeLeafAssignment(utxo: _utxo(500 * i), recipientScaled: 1000 ~/ inputs, changeScaled: 0),
        ],
      ],
      amountToken: tenTokens,
      changeToken: BigInt.zero,
      feeToken: BigInt.zero,
    );

    Future<SendOutcome> submit(WidgetRef ref, WormholeSpendPlan plan) => EncryptedSendStrategy(account: account).submit(
      ref,
      recipientAddress: _depositAddress,
      amount: tenTokens,
      fee: EncryptedFee(plan: plan),
      isPayMode: false,
    );

    testWidgets('a single input goes on without a lookup', (tester) async {
      final outcome = await submit(await pumpStrategyRef(tester), plan(1));
      expect(outcome, isA<SendNeedsProving>());
      expect(lookedUp, isEmpty);
    });

    testWidgets('several inputs to a confirmed deposit address are refused', (tester) async {
      final ref = await pumpStrategyRef(tester);
      expect(await isOneClickDepositAddress(ref, _depositAddress), isTrue);
      final outcome = await submit(ref, plan(2));
      expect((outcome as SendFailed).message, contains('single-use NEAR Intents deposit address'));
      expect(lookedUp, [_depositAddress]);
    });

    testWidgets('several inputs go on without waiting when 1Click has not answered', (tester) async {
      final outcome = await submit(await pumpStrategyRef(tester), plan(2));
      expect(outcome, isA<SendNeedsProving>());
      expect(lookedUp, isEmpty);
    });

    testWidgets('several inputs go on when 1Click was unreachable', (tester) async {
      oneClickDown = true;
      final ref = await pumpStrategyRef(tester);
      expect(await isOneClickDepositAddress(ref, _depositAddress), isFalse);
      expect(await submit(ref, plan(2)), isA<SendNeedsProving>());
      expect(lookedUp, [_depositAddress]);
    });
  });
}
