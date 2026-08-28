import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('hides error copy and clear button by default', (tester) async {
    final controller = TextEditingController(text: 'Value');
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusTextField(controller: controller, hint: 'Hint'));

    expect(find.text('Value'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('shows inline error message', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusTextField(controller: controller, error: 'Fix this'));

    expect(find.text('Fix this'), findsOneWidget);
  });

  testWidgets('clear button empties the controller', (tester) async {
    final controller = TextEditingController(text: 'Hello');
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusTextField(controller: controller, showClearButton: true));

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('requestFocus rebuilds without throwing', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await pumpField(tester, QuantusTextField(controller: controller, focusNode: focusNode));

    expect(focusNode.hasFocus, isFalse);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('obscureText and enableSuggestions are forwarded', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusTextField(controller: controller, obscureText: true, enableSuggestions: false));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
  });

  testWidgets('onSubmitted fires on IME done', (tester) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);
    String? submitted;

    await pumpField(tester, QuantusTextField(controller: controller, onSubmitted: (value) => submitted = value));

    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 'hello');
  });

  testWidgets('trailing widget is shown', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusTextField(controller: controller, trailing: const Icon(Icons.visibility_outlined)));

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    final fieldCenter = tester.getCenter(find.byType(QuantusTextField)).dy;
    final iconCenter = tester.getCenter(find.byIcon(Icons.visibility_outlined)).dy;
    expect(iconCenter, closeTo(fieldCenter, 2));
  });

  testWidgets('defaults to a single-line TextField', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusTextField(controller: controller));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, 1);
    expect(field.expands, isFalse);
    expect(field.minLines, isNull);
  });

  testWidgets('forwards multiline height, expands, and maxLines', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpField(
      tester,
      QuantusTextField(
        controller: controller,
        height: 202,
        maxLines: null,
        expands: true,
        trailing: const Icon(Icons.visibility_outlined),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, isNull);
    expect(field.minLines, isNull);
    expect(field.expands, isTrue);
    expect(tester.getSize(find.byType(QuantusTextField)).height, 202);

    final fieldTop = tester.getTopLeft(find.byType(QuantusTextField)).dy;
    final iconTop = tester.getTopLeft(find.byIcon(Icons.visibility_outlined)).dy;
    expect(iconTop - fieldTop, lessThan(30));
  });

  testWidgets('a non-focusable trailing lets keyboard next reach the following field', (tester) async {
    final first = TextEditingController();
    final second = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await pumpField(
      tester,
      Column(
        children: [
          QuantusTextField(
            controller: first,
            textInputAction: TextInputAction.next,
            trailing: QuantusIconButton.ghost(
              icon: Icons.visibility_off_outlined,
              onTap: () {},
              canRequestFocus: false,
            ),
          ),
          QuantusTextField(controller: second),
        ],
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[1].focusNode?.hasPrimaryFocus, isTrue, reason: 'next must skip the trailing button');
  });

  testWidgets('a default trailing stays reachable by focus traversal', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpField(
      tester,
      QuantusTextField(
        controller: controller,
        trailing: QuantusIconButton.ghost(icon: Icons.paste, onTap: () {}),
      ),
    );

    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: find.byIcon(Icons.paste), matching: find.byType(InkWell)).first,
    );
    expect(inkWell.canRequestFocus, isTrue, reason: 'paste must stay available to keyboard and switch users');
  });

  testWidgets('showClearButton and trailing are mutually exclusive', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    expect(
      () => QuantusTextField(
        controller: controller,
        showClearButton: true,
        trailing: const Icon(Icons.visibility_outlined),
      ),
      throwsAssertionError,
    );
  });
}
