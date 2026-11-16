import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Every call the app makes to the system clipboard.
List<MethodCall> _recordSystemClipboard(WidgetTester tester) {
  final calls = <MethodCall>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method.startsWith('Clipboard.')) calls.add(call);
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

Future<void> _pump(WidgetTester tester, CopyAction action) => tester.pumpWidget(
  Builder(
    builder: (context) => MaterialApp(
      theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
      home: Scaffold(body: Center(child: action)),
    ),
  ),
);

String _label(WidgetTester tester) => tester.widget<ToolbarAction>(find.byType(ToolbarAction)).label;

void main() {
  testWidgets('with its own copy, it copies through that and not the system clipboard', (tester) async {
    final systemCalls = _recordSystemClipboard(tester);
    final copied = <String>[];
    await _pump(
      tester,
      CopyAction(text: 'secret', copyLabel: 'Copy', copiedLabel: 'Copied', copy: (text) async => copied.add(text)),
    );

    await tester.tap(find.byType(ToolbarAction));
    await tester.pump();

    expect(copied, ['secret']);
    expect(systemCalls, isEmpty);
    expect(_label(tester), 'Copied');
    await tester.pump(CopyAction.copiedFor);
  });

  testWidgets('a copy that fails is reported and never shown as copied', (tester) async {
    final failures = <Object>[];
    await _pump(
      tester,
      CopyAction(
        text: 'secret',
        copyLabel: 'Copy',
        copiedLabel: 'Copied',
        copy: (text) async => throw PlatformException(code: 'pasteboard'),
        onFailed: failures.add,
      ),
    );

    await tester.tap(find.byType(ToolbarAction));
    await tester.pump();

    expect(failures.single, isA<PlatformException>());
    expect(_label(tester), 'Copy');
  });
}
