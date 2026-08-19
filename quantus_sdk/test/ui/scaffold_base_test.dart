import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('BaseBackground fills with v3 void', (tester) async {
    await pump(tester, const ScaffoldBase(mainContent: Text('Hello')));

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(BaseBackground), matching: find.byType(Container)).first,
    );
    expect(container.color, colors.bgVoid);
  });

  testWidgets('bottom content uses v3 hairline divider', (tester) async {
    await pump(
      tester,
      const ScaffoldBase(
        mainContent: Text('Hello'),
        bottomContent: ScaffoldBaseBottomContent(child: Text('Continue')),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(ScaffoldBaseBottomContent), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.color, colors.borderHairline);
  });

  testWidgets('refresh indicator uses v3 content and surface tokens', (tester) async {
    await pump(tester, ScaffoldBase.refreshable(onRefresh: () async {}, slivers: const [Text('Item')]));

    final indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    expect(indicator.color, colors.textContent);
    expect(indicator.backgroundColor, colors.bgSurface);
  });
}
