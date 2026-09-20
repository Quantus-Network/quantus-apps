import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/amount_input_logic.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_fee_notifier.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sender = makeAccount(1);
  final recipient = makeAccount(2);
  final spendable = BigInt.from(5) * NumberFormattingService.scaleFactorBigInt;
  final transferFee = BigInt.from(10).pow(10);
  final transferAllFee = BigInt.from(3) * transferFee;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  Future<ProviderContainer> pumpAmountScreen(WidgetTester tester, FakeSubstrateService substrate) async {
    await tester.pumpApp(
      InputAmountScreen(
        strategy: RegularSendStrategy(account: sender),
        recipientAddress: recipient.accountId,
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(sender))),
        humanReadableChecksumServiceProvider.overrideWithValue(FakeHumanReadableChecksumService()),
        effectiveMaxBalanceProviderFamily.overrideWith((ref, accountId) => AsyncValue.data(spendable)),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        substrateServiceProvider.overrideWithValue(substrate),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(InputAmountScreen)));
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key(E2EKeys.sendAmountField))).controller!.text;

  Future<void> tapContinue(WidgetTester tester) async {
    expect(tester.widget<QuantusButton>(find.byKey(const Key(E2EKeys.sendReviewButton))).isDisabled, isFalse);
    await tester.tap(find.byKey(const Key(E2EKeys.sendReviewButton)));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key(E2EKeys.sendReviewScreen)), findsOneWidget);
  }

  String formatted(ProviderContainer container, BigInt amount) => AmountInputLogic(
    exchangeRateService: container.read(exchangeRateServiceProvider),
    selectedFiat: container.read(selectedFiatCurrencyProvider),
    localeConfig: container.read(localeNumberConfigProvider),
    formattingService: container.read(numberFormattingServiceProvider),
  ).formatTokenAmount(amount);

  testWidgets('Max prices transfer_all at once and sizes the amount from that fee', (tester) async {
    final substrate = FakeSubstrateService(fee: transferFee);
    final container = await pumpAmountScreen(tester, substrate);
    expect(substrate.lastFeeCall, isNull);

    substrate.fee = transferAllFee;
    await tester.tap(find.text(container.read(l10nProvider).sendInputAmountMax));
    await tester.pump();

    expect(isTransferAll(substrate.lastFeeCall!, keepAlive: true), isTrue);
    expect(fieldText(tester), formatted(container, spendable - transferAllFee));
    expect(container.read(sendFeeProvider).settled, isTrue);
  });

  testWidgets('typing after Max goes back to pricing a plain transfer', (tester) async {
    final substrate = FakeSubstrateService(fee: transferFee);
    final container = await pumpAmountScreen(tester, substrate);
    await tester.tap(find.text(container.read(l10nProvider).sendInputAmountMax));
    await tester.pump();
    expect(isTransferAll(substrate.lastFeeCall!, keepAlive: true), isTrue);

    await tester.enterText(find.byKey(const Key(E2EKeys.sendAmountField)), '1');
    await tester.pump(SendFeeNotifier.debounce);

    expect(isTransferAll(substrate.lastFeeCall!, keepAlive: true), isFalse);
    expect(fieldText(tester), '1');
  });

  testWidgets('Continue keeps a settled quote that already priced this send', (tester) async {
    final substrate = FakeSubstrateService(fee: transferFee);
    final container = await pumpAmountScreen(tester, substrate);
    await tester.tap(find.text(container.read(l10nProvider).sendInputAmountMax));
    await tester.pump();
    expect(substrate.feeCalls, 1);

    await tapContinue(tester);

    expect(substrate.feeCalls, 1);
  });

  testWidgets('Continue prices the exact amount at once while a typed quote is still queued', (tester) async {
    final substrate = FakeSubstrateService(fee: transferFee);
    final container = await pumpAmountScreen(tester, substrate);
    await tester.tap(find.text(container.read(l10nProvider).sendInputAmountMax));
    await tester.pump();
    await tester.enterText(find.byKey(const Key(E2EKeys.sendAmountField)), '1');
    await tester.pump();
    expect(substrate.feeCalls, 1);

    await tapContinue(tester);

    expect(substrate.feeCalls, 2);
    expect(isTransferAll(substrate.lastFeeCall!, keepAlive: true), isFalse);
    final fee = container.read(sendFeeProvider);
    expect(fee.settled, isTrue);
    expect((fee.fee as RegularFee).amount, NumberFormattingService.scaleFactorBigInt);
  });
}
