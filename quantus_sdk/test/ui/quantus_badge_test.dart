import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpBadge(WidgetTester tester, Widget badge) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: badge),
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

  testWidgets('renders label in uppercase', (tester) async {
    await pumpBadge(tester, const QuantusBadge(label: 'Pending'));

    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('paints stroke and text with the tone token', (tester) async {
    final cases = <(BadgeTone, Color)>[
      (BadgeTone.neutral, colors.textMuted),
      (BadgeTone.sage, colors.semanticSage),
      (BadgeTone.sand, colors.semanticSand),
      (BadgeTone.ember, colors.semanticEmber),
      (BadgeTone.glacier, colors.semanticGlacier),
      (BadgeTone.lilac, colors.semanticLilac),
      (BadgeTone.flare, colors.accentFlare),
    ];

    for (final (tone, color) in cases) {
      await pumpBadge(tester, QuantusBadge(label: 'Badge', tone: tone));

      final text = tester.widget<Text>(find.text('BADGE'));
      expect(text.style?.color, color, reason: '$tone text');

      final border = decorationAround(tester, 'BADGE').border! as Border;
      expect(border.top.color, color, reason: '$tone stroke');
      expect(border.top.width, 1);
    }
  });

  testWidgets('uses v3 xs radius', (tester) async {
    await pumpBadge(tester, const QuantusBadge(label: 'Badge'));

    expect(decorationAround(tester, 'BADGE').borderRadius, const AppRadiusV3.standard().xsBorder);
  });
}
