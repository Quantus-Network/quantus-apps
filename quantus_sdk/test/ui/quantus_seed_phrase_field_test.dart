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

  testWidgets('is a 202px multiline field that starts obscured', (tester) async {
    final controller = ObscuringTextEditingController(text: 'secret phrase');
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusSeedPhraseField(controller: controller, hint: 'Paste your phrase'));

    expect(find.text('Paste your phrase'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(controller.obscured, isTrue);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, isNull);
    expect(field.expands, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.done);
    expect(tester.getSize(find.byType(QuantusTextField)).height, 202);
  });

  testWidgets('visibility toggle reveals and hides the phrase', (tester) async {
    final controller = ObscuringTextEditingController(text: 'secret phrase');
    addTearDown(controller.dispose);

    await pumpField(tester, QuantusSeedPhraseField(controller: controller));

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(controller.obscured, isFalse);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(controller.obscured, isTrue);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('forwards hint, error, and onChanged', (tester) async {
    final controller = ObscuringTextEditingController();
    addTearDown(controller.dispose);
    var changed = '';

    await pumpField(
      tester,
      QuantusSeedPhraseField(
        controller: controller,
        hint: 'Hint',
        error: 'Fix this',
        onChanged: (value) => changed = value,
      ),
    );

    expect(find.text('Fix this'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'one two');
    expect(changed, 'one two');
  });

  testWidgets('focus scrolls the target into view', (tester) async {
    tester.view.physicalSize = const Size(375, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ObscuringTextEditingController();
    final targetKey = GlobalKey();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 400)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    QuantusSeedPhraseField(controller: controller, scrollToOnFocus: targetKey),
                    const SizedBox(height: 800),
                    SizedBox(key: targetKey, height: 48, child: const Text('Import')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.text('Import')).dy, greaterThan(400));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.getBottomLeft(find.text('Import')).dy, lessThanOrEqualTo(400));
  });

  testWidgets('obscuring controller paints xs and restores real text', (tester) async {
    final controller = ObscuringTextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    late BuildContext captured;
    await pumpField(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(
      controller.buildTextSpan(context: captured, style: const TextStyle(), withComposing: false).toPlainText(),
      'xxxxxx',
    );
    expect(controller.text, 'secret');

    controller.obscured = false;
    expect(
      controller.buildTextSpan(context: captured, style: const TextStyle(), withComposing: false).toPlainText(),
      'secret',
    );
  });
}
