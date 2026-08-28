import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpLoader(WidgetTester tester, Widget loader, {Size size = const Size(375, 667)}) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: loader),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  CircularProgressIndicator indicator(WidgetTester tester) {
    return tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
  }

  testWidgets('defaults to v3 accentFlare', (tester) async {
    await pumpLoader(tester, const Loader());

    expect(indicator(tester).color, colors.accentFlare);
    expect(tester.getSize(find.byType(Loader)), const Size(16, 16));
  });

  testWidgets('uses the explicit color when provided', (tester) async {
    await pumpLoader(tester, Loader(color: colors.textMuted, size: 20));

    expect(indicator(tester).color, colors.textMuted);
    expect(tester.getSize(find.byType(Loader)), const Size(20, 20));
  });
}
