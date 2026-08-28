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

  testWidgets('default glyph follows the tone', (tester) async {
    await pumpBanner(
      tester,
      const QuantusBanner(tone: BannerTone.sage, message: 'Your funds are safe. Nothing left your wallet.'),
    );

    expect(find.text('Your funds are safe. Nothing left your wallet.'), findsOneWidget);
    expect(find.text('\u2713'), findsOneWidget, reason: 'success must not wear the failure mark');
    expect(find.text('!'), findsNothing);

    for (final tone in [BannerTone.sand, BannerTone.ember, BannerTone.glacier]) {
      await pumpBanner(tester, QuantusBanner(tone: tone, message: 'Status'));
      expect(find.text('!'), findsOneWidget, reason: '$tone glyph');
    }
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

  testWidgets('stacked shows uppercase label, amount, and muted caption', (tester) async {
    await pumpBanner(
      tester,
      const QuantusBanner.stacked(
        tone: BannerTone.sage,
        label: 'Your funds are safe',
        amount: '12.5 QUAN',
        message: 'Still in Account 1. Nothing left your wallet.',
      ),
    );

    expect(find.text('YOUR FUNDS ARE SAFE'), findsOneWidget);
    expect(find.text('12.5 QUAN'), findsOneWidget);
    expect(find.text('Still in Account 1. Nothing left your wallet.'), findsOneWidget);
    expect(find.text('!'), findsNothing);

    expect(tester.widget<Text>(find.text('YOUR FUNDS ARE SAFE')).style?.color, colors.semanticSage);
    expect(tester.widget<Text>(find.text('12.5 QUAN')).style?.color, colors.semanticSage);
    expect(
      tester.widget<Text>(find.text('Still in Account 1. Nothing left your wallet.')).style?.color,
      colors.textMuted,
    );
  });

  testWidgets('stacked paints 10 percent tone stroke', (tester) async {
    await pumpBanner(
      tester,
      const QuantusBanner.stacked(
        tone: BannerTone.sage,
        label: 'Your funds are safe',
        amount: '12.5 QUAN',
        message: 'Still in Account 1. Nothing left your wallet.',
      ),
    );

    final border = decorationAround(tester, '12.5 QUAN').border! as Border;
    expect(border.top.color, colors.semanticSage.useOpacity(0.10));
    expect(decorationAround(tester, '12.5 QUAN').gradient, isA<LinearGradient>());
  });
}
