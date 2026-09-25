import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const labels = ['Receive', 'Send', 'Swap'];

  Future<void> pumpHomeRow(WidgetTester tester, double textScale) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: const Size(360, 780), textScaler: TextScaler.linear(textScale)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: Padding(
                    padding: ScaffoldBase.defaultPadding,
                    child: Row(
                      spacing: 20,
                      children: [
                        for (final label in labels)
                          Expanded(
                            child: ActionCard(iconAsset: 'assets/icons/plus.svg', label: label, onTap: () {}),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final textScale in [1.0, 1.5, 2.0]) {
    testWidgets('360dp row keeps labels on one line and cards equal height at ${textScale}x text', (tester) async {
      await pumpHomeRow(tester, textScale);

      final cards = find.byType(ActionCard);
      final heights = [for (var i = 0; i < labels.length; i++) tester.getSize(cards.at(i)).height];
      expect(heights.toSet(), hasLength(1));

      for (var i = 0; i < labels.length; i++) {
        final label = find.text(labels[i]);
        expect(tester.getRect(label).width, lessThanOrEqualTo(tester.getSize(cards.at(i)).width));
        expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse);
      }
    });
  }
}
