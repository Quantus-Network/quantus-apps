import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpSkeleton(WidgetTester tester, Widget skeleton) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: skeleton),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<BoxDecoration> decorations(WidgetTester tester) {
    return tester
        .widgetList<Container>(find.descendant(of: find.byType(Skeleton), matching: find.byType(Container)))
        .map((container) => container.decoration! as BoxDecoration)
        .toList();
  }

  testWidgets('paints v3 surface fill and default height', (tester) async {
    await pumpSkeleton(tester, const Skeleton(width: 180));

    expect(tester.getSize(find.byType(Skeleton)), const Size(180, 16));

    final outer = decorations(tester).first;
    expect(outer.color, colors.bgSurface);
    expect(outer.borderRadius, const AppRadiusV3.standard().xsBorder);
  });

  testWidgets('circular constructor is a square pill of the given size', (tester) async {
    await pumpSkeleton(tester, Skeleton.circular(size: 40));

    expect(tester.getSize(find.byType(Skeleton)), const Size(40, 40));
    expect(decorations(tester).first.borderRadius, BorderRadius.circular(40));
  });

  testWidgets('shimmer highlights use v3 tokens', (tester) async {
    await pumpSkeleton(tester, const Skeleton(width: 110, height: 10));

    final gradient = decorations(tester)[1].gradient! as LinearGradient;
    expect(gradient.colors, [
      colors.bgVoid.useOpacity(0.2),
      colors.textMuted2.useOpacity(0.2),
      colors.bgVoid.useOpacity(0.2),
    ]);
  });
}
