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

  /// The bordered box the field draws its text in.
  Container box(WidgetTester tester) => tester.widget<Container>(
    find.descendant(of: find.byType(QuantusTextField), matching: find.byType(Container)).first,
  );

  testWidgets('by default the box is at least 48 high, with the theme\'s large data text', (tester) async {
    final controller = TextEditingController(text: 'Value');
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusTextField(controller: controller, hint: 'Hint'));

    final context = tester.element(find.byType(QuantusTextField));
    final decoration = box(tester).decoration! as BoxDecoration;
    expect(tester.getSize(find.byWidget(box(tester))).height, 48);
    expect(tester.getTopLeft(find.byType(EditableText)).dx, 15);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).style.fontSize,
      context.themeTextV3.dataAddressLarge.fontSize,
    );
    expect(decoration.color, context.colorsV3.bgSurface);
    expect(decoration.borderRadius, context.radiusV3.mdBorder);
  });

  testWidgets('a compact field: its padding, text style, fill and corners can be set, and the hint follows the text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    const style = TextStyle(fontFamily: 'Geist', fontSize: 13);

    await pumpField(
      tester,
      QuantusTextField(
        controller: controller,
        hint: 'Password',
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: style,
        fillColor: const Color(0xFF010203),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    final context = tester.element(find.byType(QuantusTextField));
    final decoration = box(tester).decoration! as BoxDecoration;
    expect(tester.getSize(find.byWidget(box(tester))).height, 36);
    // The padding, inside the border.
    expect(tester.getTopLeft(find.byType(EditableText)).dx, 13);
    expect(decoration.color, const Color(0xFF010203));
    expect(decoration.borderRadius, BorderRadius.circular(6));

    final text = tester.widget<EditableText>(find.byType(EditableText)).style;
    expect((text.fontFamily, text.fontSize, text.color), ('Geist', 13, context.colorsV3.textContent));
    final hint = tester.widget<Text>(find.text('Password')).style!;
    expect((hint.fontFamily, hint.fontSize, hint.color), ('Geist', 13, context.colorsV3.textMuted));
  });

  testWidgets('a single-line field of a set height centres its text in the box', (tester) async {
    final controller = TextEditingController(text: 'Value');
    addTearDown(controller.dispose);

    await pumpField(
      tester,
      QuantusTextField(controller: controller, height: 36, padding: const EdgeInsets.symmetric(horizontal: 12)),
    );

    expect(
      tester.getCenter(find.byType(EditableText)).dy,
      moreOrLessEquals(tester.getCenter(find.byWidget(box(tester))).dy, epsilon: 0.01),
    );
    // As wide as the box leaves it.
    expect(tester.getSize(find.byType(EditableText)).width, tester.getSize(find.byWidget(box(tester))).width - 2 * 13);
  });

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

  testWidgets('draws a footer inside the bordered box, under the text', (tester) async {
    final controller = TextEditingController(text: 'one two');
    addTearDown(controller.dispose);

    await pumpField(
      tester,
      QuantusTextField(
        controller: controller,
        maxLines: null,
        expands: true,
        height: 180,
        footer: const Text('Footer'),
      ),
    );

    final box = tester.getRect(find.byType(QuantusTextField));
    final text = tester.getRect(find.byType(TextField));
    final footer = tester.getRect(find.text('Footer'));
    expect(box.height, 180);
    expect(box.contains(footer.topLeft) && box.contains(footer.bottomRight), isTrue, reason: 'inside the box');
    expect(footer.top, greaterThanOrEqualTo(text.bottom), reason: 'under the text');
  });

  testWidgets('a footer needs an expanding field', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    expect(() => QuantusTextField(controller: controller, footer: const Text('Footer')), throwsAssertionError);
  });
}
