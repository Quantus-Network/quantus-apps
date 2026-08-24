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

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const address = 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEdX';

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
    await pumpSheet(tester, address, overrides: [substrateServiceProvider.overrideWithValue(FakeSubstrateService())]);

    await tester.tap(find.text('Send To This Account'));
    await tester.pump();

    expect(find.byType(InputAmountScreen), findsNothing);
    expect(find.byType(SharedAddressActionSheet), findsOneWidget);
    expect(find.text('Switch to a regular account to send'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('uses v3 sheet, type, and color tokens', (tester) async {
    await pumpSheet(tester, address);

    expect(find.byType(BottomSheetContainer), findsOneWidget);

    final title = tester.widget<Text>(find.text('Shared Acount'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.headingRow.fontSize);
    expect(title.style?.fontWeight, text.headingRow.fontWeight);

    final addressText = AddressFormattingService.splitIntoChunks(address).join(' ');
    final addressContainer = tester.widget<Container>(
      find.ancestor(of: find.text(addressText), matching: find.byType(Container)).first,
    );
    final decoration = addressContainer.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface2);
    expect(decoration.borderRadius, const AppRadiusV3.standard().mdBorder);
    expect(decoration.border?.top.color, colors.borderHairline);

    final addressLabel = tester.widget<Text>(find.text(addressText));
    expect(addressLabel.style?.color, colors.textContent);
    expect(addressLabel.style?.fontSize, text.dataAddressLarge.fontSize);

    final copyIcons = tester.widgetList<Icon>(find.byIcon(Icons.copy));
    expect(copyIcons, isNotEmpty);
    expect(copyIcons.every((icon) => icon.color == colors.textContent), isTrue);
  });
}
