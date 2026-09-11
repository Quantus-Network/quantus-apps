import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/screens/settings/preferences_settings_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('amount display renders QUAN without fiat or a switcher', (tester) async {
    await tester.pumpApp(
      const AmountDisplayWithConversion(
        amountDisplay: CurrencyDisplayState(
          primaryAmount: r'$12.34',
          secondaryAmount: '12.34',
          isFlipped: true,
          selectedFiat: FiatCurrency.usd,
        ),
      ),
    );

    expect(find.textContaining(r'$'), findsNothing);
    expect(find.textContaining('12.34'), findsOneWidget);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
  });

  testWidgets('preferences do not expose currency selection', (tester) async {
    await tester.pumpApp(
      const PreferencesSettingsScreenV2(),
      overrides: [settingsServiceProvider.overrideWithValue(FakeSettingsService())],
    );
    await tester.pump();

    expect(find.text('Currency'), findsNothing);
    expect(find.text('Fiat display preference'), findsNothing);
  });

  testWidgets('swap entry does not show USD estimates', (tester) async {
    await tester.pumpApp(
      const SwapScreen(),
      overrides: [settingsServiceProvider.overrideWithValue(FakeSettingsService())],
    );

    expect(find.textContaining(r'$'), findsNothing);
  });
}
