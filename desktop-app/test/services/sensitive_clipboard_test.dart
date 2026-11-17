import 'dart:async';

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

  _testOnMacAndWindows('a clear that fails, as when another program has the clipboard open, is tried again until '
      'it succeeds', (tester) async {
    var failures = 2;
    final calls = _recordNativeCalls(
      tester,
      answer: (call) => call.method == 'clear' && failures-- > 0 ? PlatformException(code: 'clipboard') : null,
    );
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copy('words');
    await tester.pump(SensitiveClipboard.lifetime);

    expect(calls.map((c) => c.method), ['copy', 'clear']);

    await tester.pump(SensitiveClipboard.retryDelay - const Duration(milliseconds: 1));

    expect(calls.map((c) => c.method), ['copy', 'clear']);

    await tester.pump(const Duration(milliseconds: 1));

    expect(calls.map((c) => c.method), ['copy', 'clear', 'clear']);

    await tester.pump(SensitiveClipboard.retryDelay);

    expect(calls.map((c) => c.method), ['copy', 'clear', 'clear', 'clear']);

    // That one succeeded, so nothing more is tried.
    await tester.pump(SensitiveClipboard.lifetime);

    expect(calls.map((c) => c.method), ['copy', 'clear', 'clear', 'clear']);
    expect(SensitiveClipboard.retryDelay, const Duration(seconds: 5));
  });

  _testOnMacAndWindows('a new copy while a retry is pending starts the three minutes again, without the retry', (
    tester,
  ) async {
    var failures = 1;
    final calls = _recordNativeCalls(
      tester,
      answer: (call) => call.method == 'clear' && failures-- > 0 ? PlatformException(code: 'clipboard') : null,
    );
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await clipboard.copy('words');
    await tester.pump(SensitiveClipboard.lifetime);
    await clipboard.copy('words');
    await tester.pump(SensitiveClipboard.lifetime - const Duration(seconds: 1));

    expect(calls.map((c) => c.method), ['copy', 'clear', 'copy']);

    await tester.pump(const Duration(seconds: 1));

    expect(calls.map((c) => c.method), ['copy', 'clear', 'copy', 'clear']);
  });

  _testOnMacAndWindows('dispose cancels a pending retry', (tester) async {
    final calls = _recordNativeCalls(
      tester,
      answer: (call) => call.method == 'clear' ? PlatformException(code: 'clipboard') : null,
    );
    final clipboard = SensitiveClipboard();

    await clipboard.copy('words');
    await tester.pump(SensitiveClipboard.lifetime);
    clipboard.dispose();
    await tester.pump(SensitiveClipboard.lifetime);

    expect(calls.map((c) => c.method), ['copy', 'clear']);
  });

  group('a clear that fails while it is still being answered', () {
    /// Holds each clear until the test fails it, and answers copies at once.
    (List<MethodCall>, List<Completer<void>>) recordHeldClears(WidgetTester tester) {
      final calls = <MethodCall>[];
      final heldClears = <Completer<void>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SensitiveClipboard.channel, (call) async {
        calls.add(call);
        if (call.method == 'clear') {
          final held = Completer<void>();
          heldClears.add(held);
          await held.future;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SensitiveClipboard.channel, null));
      return (calls, heldClears);
    }

    _testOnMacAndWindows('is not tried again after a newer copy, which keeps its own three minutes', (tester) async {
      final (calls, heldClears) = recordHeldClears(tester);
      final clipboard = SensitiveClipboard();
      addTearDown(clipboard.dispose);

      await clipboard.copy('words');
      await tester.pump(SensitiveClipboard.lifetime);
      await clipboard.copy('words');
      heldClears.single.completeError(PlatformException(code: 'clipboard'));
      await tester.pump(SensitiveClipboard.lifetime - const Duration(seconds: 1));

      expect(calls.map((c) => c.method), ['copy', 'clear', 'copy']);

      await tester.pump(const Duration(seconds: 1));

      expect(calls.map((c) => c.method), ['copy', 'clear', 'copy', 'clear']);
      heldClears.last.complete();
    });

    _testOnMacAndWindows('is not tried again after dispose', (tester) async {
      final (calls, heldClears) = recordHeldClears(tester);
      final clipboard = SensitiveClipboard();

      await clipboard.copy('words');
      await tester.pump(SensitiveClipboard.lifetime);
      clipboard.dispose();
      heldClears.single.completeError(PlatformException(code: 'clipboard'));
      await tester.pump(SensitiveClipboard.lifetime);

      expect(calls.map((c) => c.method), ['copy', 'clear']);
    });
  });

  testWidgets('Linux cannot copy it yet, and does not try', (tester) async {
    final calls = _recordNativeCalls(tester);
    final clipboard = SensitiveClipboard();
    addTearDown(clipboard.dispose);

    await expectLater(clipboard.copy('words'), throwsUnsupportedError);

    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
