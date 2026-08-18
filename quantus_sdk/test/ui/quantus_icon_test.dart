import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpIcon(WidgetTester tester, Widget icon) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: icon),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  SvgPicture svgOf(WidgetTester tester) => tester.widget<SvgPicture>(find.byType(SvgPicture));

  SvgAssetLoader loaderOf(WidgetTester tester) => svgOf(tester).bytesLoader as SvgAssetLoader;

  testWidgets('loads every glyph from the SDK package', (tester) async {
    for (final icon in QuantusIcons.values) {
      await pumpIcon(tester, QuantusIcon(icon));

      final loader = loaderOf(tester);
      expect(loader.assetName, icon.assetPath, reason: '$icon asset');
      expect(loader.packageName, 'quantus_sdk', reason: '$icon package');
    }
  });

  testWidgets('defaults to 20px muted tint', (tester) async {
    await pumpIcon(tester, const QuantusIcon(QuantusIcons.plus));

    final svg = svgOf(tester);
    expect(svg.width, 20);
    expect(svg.height, 20);
    expect(svg.colorFilter, ColorFilter.mode(colors.textMuted, BlendMode.srcIn));
    expect(tester.getSize(find.byType(QuantusIcon)), const Size(20, 20));
  });

  testWidgets('honors size and color overrides', (tester) async {
    await pumpIcon(tester, QuantusIcon(QuantusIcons.lock, size: 16, color: colors.accentFlare));

    final svg = svgOf(tester);
    expect(svg.width, 16);
    expect(svg.height, 16);
    expect(svg.colorFilter, ColorFilter.mode(colors.accentFlare, BlendMode.srcIn));
    expect(tester.getSize(find.byType(QuantusIcon)), const Size(16, 16));
  });
}
