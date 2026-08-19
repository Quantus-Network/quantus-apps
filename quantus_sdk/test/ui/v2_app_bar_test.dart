import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('title uses v3 screen title and content color', (tester) async {
    await pump(tester, const V2AppBar(title: 'Settings', showBackButton: false));

    final title = tester.widget<Text>(find.text('Settings'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleScreen.fontSize);
    expect(title.style?.fontWeight, text.titleScreen.fontWeight);
    expect(title.style?.height, text.titleScreen.height);
  });

  testWidgets('default back button uses v3 chevron and content color', (tester) async {
    await pump(tester, const AppBackButton());

    expect(find.byType(QuantusIcon), findsOneWidget);
    final icon = tester.widget<QuantusIcon>(find.byType(QuantusIcon));
    expect(icon.icon, QuantusIcons.chevronLeft);
    expect(icon.color, colors.textContent);

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.colorFilter, ColorFilter.mode(colors.textContent, BlendMode.srcIn));
  });
}
