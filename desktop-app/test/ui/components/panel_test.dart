import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/panel_resize_handle.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool reduceMotion = false}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(body: SizedBox(width: 400, height: 300, child: child)),
      ),
    ),
  );
}

BoxBorder? _border(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(
                  find.descendant(of: find.byType(Panel), matching: find.byType(DecoratedBox)).first,
                )
                .decoration
            as BoxDecoration)
        .border;

void main() {
  group('a panel', () {
    testWidgets('at rest has a hairline under its header', (tester) async {
      await _pump(tester, const Panel(title: 'Activity', child: SizedBox()));

      expect(find.byKey(Panel.busyLineKey), findsNothing);
      expect(find.descendant(of: find.byType(Panel), matching: find.byType(MenuDivider)), findsOneWidget);
    });

    testWidgets('fetching runs a line along that hairline, and keeps it running', (tester) async {
      await _pump(tester, const Panel(title: 'Activity', isBusy: true, child: SizedBox()));

      expect(find.byKey(Panel.busyLineKey), findsOneWidget);
      expect(find.descendant(of: find.byType(Panel), matching: find.byType(MenuDivider)), findsNothing);
      expect(tester.hasRunningAnimations, isTrue);

      await _pump(tester, const Panel(title: 'Activity', child: SizedBox()));
      expect(find.byKey(Panel.busyLineKey), findsNothing);
    });

    testWidgets('with the system asking for less motion, the line is lit but still', (tester) async {
      await _pump(tester, const Panel(title: 'Activity', isBusy: true, child: SizedBox()), reduceMotion: true);

      expect(find.byKey(Panel.busyLineKey), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the one the keys are in has a lighter border', (tester) async {
      await _pump(tester, const Panel(title: 'Activity', child: SizedBox()));
      final context = tester.element(find.byType(Panel));
      expect(_border(tester), Border.all(color: context.colorsV3.borderHairline));

      await _pump(tester, const Panel(title: 'Activity', isFocused: true, child: SizedBox()));
      expect(_border(tester), Border.all(color: context.colorsV3.textContent.useOpacity(0.28)));
    });
  });

  group('a resize handle', () {
    Future<List<double>> dragged(WidgetTester tester, ResizedPanel resizes, double by) async {
      final widths = <double>[];
      await _pump(
        tester,
        // Stretched, as the window's panels are.
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: SizedBox()),
            PanelResizeHandle(width: 380, resizes: resizes, onResize: widths.add, onResizeEnd: () {}),
            const SizedBox(width: 100),
          ],
        ),
      );
      await tester.timedDrag(find.byType(PanelResizeHandle), Offset(by, 0), const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      return widths;
    }

    testWidgets('at the right of its panel widens it as it is dragged right', (tester) async {
      expect((await dragged(tester, ResizedPanel.left, 60)).last, 440);
    });

    testWidgets('at the left of its panel widens it as it is dragged left', (tester) async {
      expect((await dragged(tester, ResizedPanel.right, -60)).last, 440);
    });
  });
}
