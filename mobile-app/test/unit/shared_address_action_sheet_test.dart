import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:resonance_network_wallet/v2/components/shared_address_action_sheet.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  Future<void> pumpSheet(WidgetTester tester, String address, {List<Override> overrides = const []}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.darkTheme(context),
              home: Scaffold(body: SharedAddressActionSheet(address: address)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Send To This Account does not navigate for an invalid address', (tester) async {
    await pumpSheet(tester, 'not-a-valid-address');

    await tester.tap(find.text('Send To This Account'));
    await tester.pump();

    expect(find.byType(InputAmountScreen), findsNothing);
    expect(find.text('Invalid address'), findsOneWidget);

    // Let the error toast (10s duration) dismiss so no ticker leaks.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Send To This Account warns and keeps the sheet open without a regular account', (tester) async {
    await pumpSheet(
      tester,
      'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEdX',
      overrides: [substrateServiceProvider.overrideWithValue(FakeSubstrateService())],
    );

    await tester.tap(find.text('Send To This Account'));
    await tester.pump();

    expect(find.byType(InputAmountScreen), findsNothing);
    expect(find.byType(SharedAddressActionSheet), findsOneWidget);
    expect(find.text('Switch to a regular account to send'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
  });
}
