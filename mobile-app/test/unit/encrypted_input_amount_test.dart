import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/exchange_rate_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions.dart';
import '../fakes.dart';

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

EncryptedAccountState _state(List<WormholeUtxo> utxos, {BigInt? pending}) => EncryptedAccountState(
  accountId: 'addr',
  ownAddresses: const {'addr'},
  received: utxos,
  spends: const {},
  utxos: utxos,
  pendingChangeToken: pending ?? BigInt.zero,
  nextIndex: 0,
  nextChangeIndex: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help';
  final sender = makeAccount(1, accountType: AccountType.encrypted);
  final recipient = makeAccount(2);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  Future<ProviderContainer> pumpAmountScreen(WidgetTester tester, Future<EncryptedAccountState> state) async {
    await tester.pumpApp(
      InputAmountScreen(
        strategy: EncryptedSendStrategy(account: sender),
        recipientAddress: recipient.accountId,
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(sender))),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        encryptedStateProvider.overrideWith((ref, walletIndex) => state),
      ],
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(InputAmountScreen)));
  }

  QuantusButton reviewButton(WidgetTester tester) =>
      tester.widget<QuantusButton>(find.byKey(const Key(E2EKeys.sendReviewButton)));

  String buttonLabel(WidgetTester tester) {
    final button = find.byKey(const Key(E2EKeys.sendReviewButton));
    return tester.widget<Text>(find.descendant(of: button, matching: find.byType(Text))).data!;
  }

  Future<void> enterAmount(WidgetTester tester, String amount) async {
    await tester.enterText(find.byKey(const Key(E2EKeys.sendAmountField)), amount);
    await tester.pump();
  }

  String amountText(ProviderContainer container, BigInt amount) => container
      .read(l10nProvider)
      .commonAmountBalance(
        container.read(numberFormattingServiceProvider).formatBalance(amount),
        AppConstants.tokenSymbol,
      );

  testWidgets('shows the spendable balance, with change still pending on its own line', (tester) async {
    final pending = wormholeTokenFromScaled(700);
    final container = await pumpAmountScreen(tester, Future.value(_state([_utxo(300)], pending: pending)));
    final l10n = container.read(l10nProvider);

    expect(find.text(amountText(container, wormholeTokenFromScaled(300))), findsOneWidget);
    final pendingLine = tester.widget<Text>(find.byKey(const Key(E2EKeys.sendInputAmountPending)));
    expect(pendingLine.data, '${l10n.sendInputAmountPending} ${amountText(container, pending)}');
  });

  testWidgets('no pending line when nothing is pending', (tester) async {
    await pumpAmountScreen(tester, Future.value(_state([_utxo(300)])));

    expect(find.byKey(const Key(E2EKeys.sendInputAmountPending)), findsNothing);
  });

  testWidgets('a shortfall names the pending change', (tester) async {
    final pending = wormholeTokenFromScaled(700);
    final container = await pumpAmountScreen(tester, Future.value(_state([_utxo(300)], pending: pending)));
    final l10n = container.read(l10nProvider);
    final fmt = container.read(numberFormattingServiceProvider);

    await enterAmount(tester, '5');

    expect(reviewButton(tester).isDisabled, isTrue);
    expect(
      buttonLabel(tester),
      l10n.encryptedSendInsufficientWithPending(fmt.formatBalance(pending), AppConstants.tokenSymbol),
    );
  });

  testWidgets('a shortfall with nothing pending is a plain insufficient balance', (tester) async {
    final container = await pumpAmountScreen(tester, Future.value(_state([_utxo(300)])));
    final l10n = container.read(l10nProvider);

    await enterAmount(tester, '5');

    expect(reviewButton(tester).isDisabled, isTrue);
    expect(buttonLabel(tester), l10n.sendLogicInsufficientBalance);
  });

  testWidgets('an amount typed before the balance is known is not called unaffordable', (tester) async {
    final loading = Completer<EncryptedAccountState>();
    final container = await pumpAmountScreen(tester, loading.future);
    final l10n = container.read(l10nProvider);

    await enterAmount(tester, '5');

    expect(reviewButton(tester).isDisabled, isTrue);
    expect(buttonLabel(tester), l10n.sendLogicReviewSend);
    expect(find.text('...'), findsOneWidget);

    loading.complete(_state([_utxo(1000)]));
    await tester.pump();

    expect(reviewButton(tester).isDisabled, isFalse);
    expect(buttonLabel(tester), l10n.sendLogicReviewSend);
  });
}
