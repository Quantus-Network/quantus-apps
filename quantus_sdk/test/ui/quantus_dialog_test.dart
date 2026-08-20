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

  Future<void> pumpShownDialog(WidgetTester tester, {required Future<void> Function(bool result) onResult}) async {
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
                      final result = await showQuantusDialog(
                        context,
                        title: 'Dialog title?',
                        body: 'Consequences.',
                        actionLabel: 'Label',
                      );
                      await onResult(result);
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
  }

  BoxDecoration decorationAround(WidgetTester tester, String text) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  QuantusButton actionButton(WidgetTester tester, String label) {
    return tester.widget<QuantusButton>(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));
  }

  testWidgets('shows title, body, action, and Cancel', (tester) async {
    await pumpDialog(
      tester,
      QuantusDialog(
        title: 'Dialog title?',
        body: 'One or two sentences stating consequences plainly. Nothing has been sent.',
        actionLabel: 'Label',
        onAction: () {},
        onCancel: () {},
      ),
    );

    expect(find.text('Dialog title?'), findsOneWidget);
    expect(find.text('One or two sentences stating consequences plainly. Nothing has been sent.'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('action uses primary variant by default', (tester) async {
    await pumpDialog(
      tester,
      QuantusDialog(
        title: 'Dialog title?',
        body: 'Consequences.',
        actionLabel: 'Label',
        onAction: () {},
        onCancel: () {},
      ),
    );

    expect(actionButton(tester, 'Label').variant, ButtonVariant.primary);
  });

  testWidgets('action uses danger variant when destructive', (tester) async {
    await pumpDialog(
      tester,
      QuantusDialog(
        title: 'Dialog title?',
        body: 'Consequences.',
        actionLabel: 'Label',
        isDestructive: true,
        onAction: () {},
        onCancel: () {},
      ),
    );

    expect(actionButton(tester, 'Label').variant, ButtonVariant.danger);
    expect(actionButton(tester, 'Cancel').variant, ButtonVariant.secondary);
  });

  testWidgets('stacks Cancel below the primary action', (tester) async {
    await pumpDialog(
      tester,
      QuantusDialog(
        title: 'Dialog title?',
        body: 'Consequences.',
        actionLabel: 'Label',
        onAction: () {},
        onCancel: () {},
      ),
    );

    expect(tester.getTopLeft(find.text('Cancel')).dy, greaterThan(tester.getTopLeft(find.text('Label')).dy));
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

  testWidgets('tapping Cancel invokes the cancel callback', (tester) async {
    var cancelled = false;
    await pumpDialog(
      tester,
      QuantusDialog(
        title: 'Dialog title?',
        body: 'Consequences.',
        actionLabel: 'Label',
        onAction: () {},
        onCancel: () => cancelled = true,
      ),
    );

    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
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
    await pumpShownDialog(tester, onResult: (confirmed) async => result = confirmed);

    await tester.tap(find.text('Label'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('showQuantusDialog returns false when Cancel is tapped', (tester) async {
    bool? result;
    await pumpShownDialog(tester, onResult: (confirmed) async => result = confirmed);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
