import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: dialog),
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

  testWidgets('shows title, body, and action label', (tester) async {
    await pumpDialog(
      tester,
      QuantusDialog(
        title: 'Dialog title?',
        body: 'One or two sentences stating consequences plainly. Nothing has been sent.',
        actionLabel: 'Label',
        onAction: () {},
      ),
    );

    expect(find.text('Dialog title?'), findsOneWidget);
    expect(find.text('One or two sentences stating consequences plainly. Nothing has been sent.'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
  });

  testWidgets('tapping the action invokes the callback', (tester) async {
    var tapped = false;
    await pumpDialog(
      tester,
      QuantusDialog(title: 'Dialog title?', body: 'Consequences.', actionLabel: 'Label', onAction: () => tapped = true),
    );

    await tester.tap(find.text('Label'));
    expect(tapped, isTrue);
  });

  testWidgets('paints surface fill and emphasis border', (tester) async {
    await pumpDialog(
      tester,
      QuantusDialog(title: 'Dialog title?', body: 'Consequences.', actionLabel: 'Label', onAction: () {}),
    );

    final decoration = decorationAround(tester, 'Dialog title?');
    expect(decoration.color, colors.bgSurface);
    final border = decoration.border! as Border;
    expect(border.top.color, colors.borderEmphasis);
    expect(border.top.width, 1);
  });

  testWidgets('uses v3 lg radius', (tester) async {
    await pumpDialog(
      tester,
      QuantusDialog(title: 'Dialog title?', body: 'Consequences.', actionLabel: 'Label', onAction: () {}),
    );

    expect(decorationAround(tester, 'Dialog title?').borderRadius, const AppRadiusV3.standard().lgBorder);
  });

  testWidgets('showQuantusDialog returns true when the action is tapped', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () async {
                      result = await showQuantusDialog(
                        context,
                        title: 'Dialog title?',
                        body: 'Consequences.',
                        actionLabel: 'Label',
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Label'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
