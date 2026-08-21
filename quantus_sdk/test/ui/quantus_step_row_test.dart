import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpRow(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: row),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder pendingDot() {
    return find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == colors.bgSurface2 &&
          decoration.shape == BoxShape.circle;
    });
  }

  testWidgets('done paints sage check and muted label', (tester) async {
    await pumpRow(tester, const QuantusStepRow(state: StepRowState.done, label: 'Preparing'));

    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('✓'), findsOneWidget);
    expect(find.text('◌'), findsNothing);

    final mark = tester.widget<Text>(find.text('✓'));
    expect(mark.style?.color, colors.semanticSage);
    expect(mark.style?.fontSize, 13);
    expect(mark.style?.fontFamily, AppTextTheme.fontFamily);

    final label = tester.widget<Text>(find.text('Preparing'));
    expect(label.style?.color, colors.textMuted2);
    expect(label.style?.fontSize, text.body.fontSize);
    expect(label.style?.fontWeight, text.body.fontWeight);
  });

  testWidgets('active paints spinning flare mark, content label, and uppercase substate', (tester) async {
    await pumpRow(
      tester,
      const QuantusStepRow(state: StepRowState.active, label: 'Building privacy proof', substate: 'substate · detail'),
    );

    expect(find.text('Building privacy proof'), findsOneWidget);
    expect(find.text('◌'), findsOneWidget);
    expect(find.descendant(of: find.byType(QuantusStepRow), matching: find.byType(RotationTransition)), findsOneWidget);
    expect(find.text('SUBSTATE · DETAIL'), findsOneWidget);
    expect(find.text('substate · detail'), findsNothing);

    final mark = tester.widget<Text>(find.text('◌'));
    expect(mark.style?.color, colors.accentFlare);
    expect(mark.style?.fontSize, 13);

    final label = tester.widget<Text>(find.text('Building privacy proof'));
    expect(label.style?.color, colors.textContent);
    expect(label.style?.fontWeight, text.bodyEmphasis.fontWeight);

    final substate = tester.widget<Text>(find.text('SUBSTATE · DETAIL'));
    expect(substate.style?.color, colors.textMuted2);
    expect(substate.style?.fontSize, 10);
    expect(substate.style?.letterSpacing, 0.8);
    expect(substate.style?.fontFamily, AppTextTheme.fontFamilySecondary);
    expect(substate.style?.fontWeight, FontWeight.w400);
  });

  testWidgets('pending paints muted dot and hides substate', (tester) async {
    await pumpRow(
      tester,
      const QuantusStepRow(state: StepRowState.pending, label: 'Submitting to network', substate: 'hidden'),
    );

    expect(find.text('Submitting to network'), findsOneWidget);
    expect(find.text('✓'), findsNothing);
    expect(find.text('HIDDEN'), findsNothing);
    expect(pendingDot(), findsOneWidget);
    expect(tester.getSize(pendingDot()), const Size(5, 5));

    final label = tester.widget<Text>(find.text('Submitting to network'));
    expect(label.style?.color, colors.textMuted2);
  });

  testWidgets('ended paints sand mark, content label, and substate', (tester) async {
    await pumpRow(tester, const QuantusStepRow(state: StepRowState.ended, label: 'Cancelled', substate: 'user abort'));

    expect(find.text('⊘'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('USER ABORT'), findsOneWidget);
    expect(find.descendant(of: find.byType(QuantusStepRow), matching: find.byType(RotationTransition)), findsNothing);

    final mark = tester.widget<Text>(find.text('⊘'));
    expect(mark.style?.color, colors.semanticSand);

    final label = tester.widget<Text>(find.text('Cancelled'));
    expect(label.style?.color, colors.textContent);
    expect(label.style?.fontWeight, text.bodyEmphasis.fontWeight);
  });

  testWidgets('expands to the available width', (tester) async {
    await pumpRow(
      tester,
      const SizedBox(
        width: 300,
        child: QuantusStepRow(state: StepRowState.done, label: 'Preparing'),
      ),
    );

    expect(tester.getSize(find.byType(QuantusStepRow)).width, 300);
  });

  testWidgets('rebuilding with a new state replaces the mark', (tester) async {
    await pumpRow(tester, const QuantusStepRow(state: StepRowState.pending, label: 'Preparing'));
    expect(pendingDot(), findsOneWidget);

    await pumpRow(tester, const QuantusStepRow(state: StepRowState.active, label: 'Preparing'));
    expect(find.text('◌'), findsOneWidget);
    expect(find.descendant(of: find.byType(QuantusStepRow), matching: find.byType(RotationTransition)), findsOneWidget);
    expect(pendingDot(), findsNothing);
  });
}
