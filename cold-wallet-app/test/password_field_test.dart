import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/password_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpField(WidgetTester tester, PasswordField field) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: field),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('wraps QuantusTextField and starts obscured', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await pumpField(tester, PasswordField(controller: controller, hintText: 'Password'));

    expect(find.byType(QuantusTextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('visibility toggle reveals the password', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await pumpField(tester, PasswordField(controller: controller, hintText: 'Password'));

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.visibility_outlined)).color, colors.textMuted);
  });
}
