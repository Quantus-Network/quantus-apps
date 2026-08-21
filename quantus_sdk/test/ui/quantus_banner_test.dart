import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpBanner(WidgetTester tester, Widget banner) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: banner),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration decorationAround(WidgetTester tester, String text) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('shows message and default glyph', (tester) async {
    await pumpBanner(
      tester,
      const QuantusBanner(tone: BannerTone.sage, message: 'Your funds are safe. Nothing left your wallet.'),
    );

    expect(find.text('Your funds are safe. Nothing left your wallet.'), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
  });

  testWidgets('custom leading replaces the default glyph', (tester) async {
    await pumpBanner(
      tester,
      const QuantusBanner(tone: BannerTone.sand, message: 'The deposit window ended.', leading: Icon(Icons.schedule)),
    );

    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('!'), findsNothing);
  });

  testWidgets('paints 10 percent tone stroke and a vertical fill', (tester) async {
    final cases = <(BannerTone, Color)>[
      (BannerTone.sage, colors.semanticSage),
      (BannerTone.sand, colors.semanticSand),
      (BannerTone.ember, colors.semanticEmber),
      (BannerTone.glacier, colors.semanticGlacier),
    ];

    for (final (tone, color) in cases) {
      await pumpBanner(tester, QuantusBanner(tone: tone, message: 'Status'));

      final border = decorationAround(tester, 'Status').border! as Border;
      expect(border.top.color, color.useOpacity(0.10), reason: '$tone stroke');
      expect(decorationAround(tester, 'Status').gradient, isA<LinearGradient>(), reason: '$tone fill');
    }
  });

  testWidgets('uses v3 md radius', (tester) async {
    await pumpBanner(tester, const QuantusBanner(tone: BannerTone.glacier, message: 'Waiting'));

    expect(decorationAround(tester, 'Waiting').borderRadius, const AppRadiusV3.standard().mdBorder);
  });
}
