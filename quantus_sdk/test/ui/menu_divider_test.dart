import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpDivider(WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: const Scaffold(body: MenuDivider()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('paints v3 borderHairline', (tester) async {
    await pumpDivider(tester);

    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.color, colors.borderHairline);
    expect(divider.height, 1);
  });
}
