import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pumpField(WidgetTester tester, Widget field) async {
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

    await pumpField(tester, QuantusPasswordField(controller: controller, hint: 'Password'));

    expect(find.byType(QuantusTextField), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.textInputAction, TextInputAction.next);
  });

  testWidgets('visibility toggle reveals and hides the password', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusPasswordField(controller: controller, hint: 'Password'));

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    var field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.visibility_outlined)).color, colors.textContent);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('uses done when onSubmitted is set and forwards error', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var submitted = false;

    await pumpField(
      tester,
      QuantusPasswordField(
        controller: controller,
        hint: 'Password',
        error: 'Incorrect password',
        onSubmitted: (_) => submitted = true,
      ),
    );

    expect(find.text('Incorrect password'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.done);

    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, isTrue);
  });
}
