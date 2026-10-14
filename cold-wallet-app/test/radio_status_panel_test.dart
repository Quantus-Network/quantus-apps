import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/radio_status_panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();

  Future<void> pumpPanel(WidgetTester tester, List<ConnectivityResult> results) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Scaffold(body: RadioStatusPanel(results: results)),
        ),
      ),
    );
    await tester.pump();
  }

  Text valueOf(WidgetTester tester, String label) =>
      tester.widgetList<Text>(find.descendant(of: find.widgetWithText(Row, label), matching: find.byType(Text))).last;

  testWidgets('lists WI-FI, CELLULAR and BLUETOOTH in order with ON in ember and OFF in sage', (tester) async {
    await pumpPanel(tester, const [ConnectivityResult.wifi, ConnectivityResult.mobile]);

    final labels = ['WI-FI', 'CELLULAR', 'BLUETOOTH'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.getTopLeft(find.text('WI-FI')).dy, lessThan(tester.getTopLeft(find.text('CELLULAR')).dy));
    expect(tester.getTopLeft(find.text('CELLULAR')).dy, lessThan(tester.getTopLeft(find.text('BLUETOOTH')).dy));

    final wifi = valueOf(tester, 'WI-FI');
    expect(wifi.data, 'ON');
    expect(wifi.style?.color, colors.semanticEmber);
    expect(wifi.style?.fontSize, text.dataAddress.fontSize);
    expect(wifi.style?.fontFamily, AppTextThemeV3.fontFamilySecondary);

    expect(valueOf(tester, 'CELLULAR').data, 'ON');

    final bluetooth = valueOf(tester, 'BLUETOOTH');
    expect(bluetooth.data, 'OFF');
    expect(bluetooth.style?.color, colors.semanticSage);
  });

  testWidgets('reports every radio off when the platform lists none', (tester) async {
    await pumpPanel(tester, const []);

    expect(find.text('OFF'), findsNWidgets(3));
    expect(find.text('ON'), findsNothing);
  });

  testWidgets('uses the surface panel and mono spec label tokens', (tester) async {
    await pumpPanel(tester, const [ConnectivityResult.none]);

    final panel = tester.widget<Container>(
      find.ancestor(of: find.text('WI-FI'), matching: find.byType(Container)).last,
    );
    final decoration = panel.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface);
    expect(decoration.borderRadius, radius.mdBorder);
    expect((decoration.border as Border?)?.top.color, colors.borderHairline);

    final label = tester.widget<Text>(find.text('WI-FI'));
    expect(label.style?.color, colors.textMuted2);
    expect(label.style?.fontSize, 10);
    expect(label.style?.letterSpacing, 1);
    expect(label.style?.fontFamily, AppTextThemeV3.fontFamilySecondary);
  });
}
