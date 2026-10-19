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

  testWidgets('lists WI-FI, CELLULAR and BLUETOOTH in order, CONNECTED in ember and NOT CONNECTED in sage', (
    tester,
  ) async {
    await pumpPanel(tester, const [ConnectivityResult.wifi, ConnectivityResult.mobile]);

    final labels = ['WI-FI', 'CELLULAR', 'BLUETOOTH'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.getTopLeft(find.text('WI-FI')).dy, lessThan(tester.getTopLeft(find.text('CELLULAR')).dy));
    expect(tester.getTopLeft(find.text('CELLULAR')).dy, lessThan(tester.getTopLeft(find.text('BLUETOOTH')).dy));

    final wifi = valueOf(tester, 'WI-FI');
    expect(wifi.data, 'CONNECTED');
    expect(wifi.style?.color, colors.semanticEmber);
    expect(wifi.style?.fontSize, text.dataAddress.fontSize);
    expect(wifi.style?.fontFamily, AppTextThemeV3.fontFamilySecondary);

    expect(valueOf(tester, 'CELLULAR').data, 'CONNECTED');

    final bluetooth = valueOf(tester, 'BLUETOOTH');
    expect(bluetooth.data, 'NOT CONNECTED');
    expect(bluetooth.style?.color, colors.semanticSage);
    expect(find.text('ON'), findsNothing);
    expect(find.text('OFF'), findsNothing);
  });

  testWidgets('says not connected, never off, when the platform lists nothing', (tester) async {
    await pumpPanel(tester, const []);

    expect(find.text('NOT CONNECTED'), findsNWidgets(3));
    expect(find.text('CONNECTED'), findsNothing);
    expect(find.text('OFF'), findsNothing);
  });

  Future<void> bluetoothNotReported(WidgetTester tester) async {
    await pumpPanel(tester, const [ConnectivityResult.wifi]);

    final bluetooth = valueOf(tester, 'BLUETOOTH');
    expect(bluetooth.data, 'NOT REPORTED');
    expect(bluetooth.style?.color, colors.textMuted);
    expect(valueOf(tester, 'WI-FI').data, 'CONNECTED');
    expect(valueOf(tester, 'CELLULAR').data, 'NOT CONNECTED');
  }

  testWidgets(
    'on iOS, where the platform never reports Bluetooth, the row says so',
    bluetoothNotReported,
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

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
