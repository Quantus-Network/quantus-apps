import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';

/// Records the calls the app makes to the native clipboard, which answers
/// with [answer] (null for success).
List<MethodCall> _recordNativeCalls(WidgetTester tester, {Object? Function(MethodCall call)? answer}) {
  final calls = <MethodCall>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SensitiveClipboard.channel, (call) async {
    calls.add(call);
    final error = answer?.call(call);
    if (error != null) throw error;
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SensitiveClipboard.channel, null));
  return calls;
}

/// A test run as the macOS app and as the Windows app, the two that copy.
void _testOnMacAndWindows(String description, WidgetTesterCallback body) {
  testWidgets(description, body, variant: const TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.windows}));
}

void main() {
  _testOnMacAndWindows('copy hands the text to the native side, and nothing else yet', (tester) async {
    final calls = _recordNativeCalls(tester);
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copy('twenty four words');

    expect(calls.single.method, 'copy');
    expect(calls.single.arguments, {'text': 'twenty four words'});
    // Leaves no clear pending past the test.
    clipboard.dispose();
  });

  _testOnMacAndWindows('a failed copy is not hidden, and nothing is cleared later', (tester) async {
    final calls = _recordNativeCalls(
      tester,
      answer: (call) => call.method == 'copy' ? PlatformException(code: 'pasteboard') : null,
    );
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await expectLater(clipboard.copy('words'), throwsA(isA<PlatformException>()));
    await tester.pump(SensitiveClipboard.lifetime);

    expect(calls.map((c) => c.method), ['copy']);
  });

  _testOnMacAndWindows('the copy is cleared three minutes later, not before', (tester) async {
    final calls = _recordNativeCalls(tester);
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copy('words');
    await tester.pump(SensitiveClipboard.lifetime - const Duration(seconds: 1));

    expect(calls.map((c) => c.method), ['copy']);

    await tester.pump(const Duration(seconds: 1));

    expect(SensitiveClipboard.lifetime, const Duration(minutes: 3));
    expect(calls.map((c) => c.method), ['copy', 'clear']);
  });

  _testOnMacAndWindows('a second copy starts the three minutes again, and clears once', (tester) async {
    final calls = _recordNativeCalls(tester);
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copy('words');
    await tester.pump(const Duration(minutes: 2));
    await clipboard.copy('words');
    await tester.pump(const Duration(minutes: 2));

    expect(calls.map((c) => c.method), ['copy', 'copy']);

    await tester.pump(const Duration(minutes: 1));
    await tester.pump(SensitiveClipboard.lifetime);

    expect(calls.map((c) => c.method), ['copy', 'copy', 'clear']);
  });

  testWidgets('Linux cannot copy it yet, and does not try', (tester) async {
    final calls = _recordNativeCalls(tester);
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await expectLater(clipboard.copy('words'), throwsUnsupportedError);

    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
