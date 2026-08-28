import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpSheet(WidgetTester tester, Widget sheet) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: sheet),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> showViaApi(WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => BottomSheetContainer.show<void>(
                    context,
                    builder: (_) => const BottomSheetContainer(title: 'Locked', child: Text('body')),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationAround(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  Container sheetContainer(WidgetTester tester, String label) {
    return tester.widget<Container>(find.ancestor(of: find.text(label), matching: find.byType(Container)).first);
  }

  Container? handleContainer(WidgetTester tester) {
    for (final container in tester.widgetList<Container>(find.byType(Container))) {
      if (container.constraints?.maxWidth == 36 && container.constraints?.maxHeight == 4) {
        return container;
      }
    }
    return null;
  }

  BottomSheetContainer sheet() {
    return const BottomSheetContainer(title: 'Sheet Title', child: Text('Slot'));
  }

  testWidgets('shows title and content slot', (tester) async {
    await pumpSheet(tester, sheet());

    expect(find.text('Sheet Title'), findsOneWidget);
    expect(find.text('Slot'), findsOneWidget);
  });

  testWidgets('omits the close icon', (tester) async {
    await pumpSheet(tester, sheet());

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('title uses heading row and content color', (tester) async {
    await pumpSheet(tester, sheet());

    final title = tester.widget<Text>(find.text('Sheet Title'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.headingRow.fontSize);
    expect(title.style?.fontWeight, text.headingRow.fontWeight);
  });

  testWidgets('paints surface fill without a border', (tester) async {
    await pumpSheet(tester, sheet());

    final decoration = decorationAround(tester, 'Sheet Title');
    expect(decoration.color, colors.bgSurface);
    expect(decoration.border, isNull);
  });

  testWidgets('uses v3 lg radius', (tester) async {
    await pumpSheet(tester, sheet());

    expect(decorationAround(tester, 'Sheet Title').borderRadius, const AppRadiusV3.standard().lgBorder);
  });

  testWidgets('pads 24/16-32', (tester) async {
    await pumpSheet(tester, sheet());

    expect(sheetContainer(tester, 'Sheet Title').padding, const EdgeInsets.fromLTRB(24, 16, 24, 32));
  });

  testWidgets('handle is 36 by 4 in surface-2', (tester) async {
    await pumpSheet(tester, sheet());

    final handle = handleContainer(tester);
    expect(handle, isNotNull);
    final decoration = handle!.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface2);
  });

  testWidgets('takes the full available width', (tester) async {
    await pumpSheet(tester, sheet());

    expect(
      tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox)).any((box) => box.constraints.maxWidth == 362),
      isFalse,
    );
    expect(tester.getSize(find.byType(BottomSheetContainer)).width, tester.getSize(find.byType(Scaffold)).width);
  });

  testWidgets('show defaults to a draggable, barrier-dismissible sheet', (tester) async {
    await showViaApi(tester);

    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag, isTrue);
    expect(ModalRoute.of(tester.element(find.text('Locked')))!.barrierDismissible, isTrue);
  });

  testWidgets('show pops when tapping the area above the sheet', (tester) async {
    await showViaApi(tester);
    expect(find.text('Locked'), findsOneWidget);

    final sheetTop = tester.getTopLeft(find.byType(BottomSheetContainer)).dy;
    expect(sheetTop, greaterThan(8));

    await tester.tapAt(Offset(tester.getSize(find.byType(MaterialApp)).width / 2, 8));
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsNothing);
  });

  testWidgets('show stays open when tapping the sheet', (tester) async {
    await showViaApi(tester);

    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });
}
