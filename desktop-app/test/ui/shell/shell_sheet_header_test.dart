import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';

import '../../fakes.dart';

/// Opens the app on a wallet with [mainAccount], then [sheet].
Future<void> _openSheet(WidgetTester tester, ShellSheet sheet) async {
  final device = FakeWalletDevice()..store([mainAccount]);
  await pumpShell(
    tester,
    overrides: [
      ...device.overrides,
      systemApprovalProvider.overrideWithValue(FakeUserApproval()),
      sensitiveClipboardProvider.overrideWithValue(FakeSensitiveClipboard()),
    ],
  );
  ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(shellSheetProvider.notifier).open(sheet);
  await tester.pumpAndSettle();
}

/// Opens Settings, then its Recovery Phrase step.
Future<void> _openRecoveryPhraseStep(WidgetTester tester) async {
  await _openSheet(tester, ShellSheet.settings);
  await tester.tap(find.byKey(SettingsSheet.recoveryPhraseRowKey));
  await tester.pumpAndSettle();
}

/// The left and right edges of the sheet's content.
({double left, double right}) _contentEdges(WidgetTester tester) {
  final sheet = tester.getRect(find.byType(ShellSheetView));
  return (left: sheet.left + ShellSheetView.padding, right: sheet.right - ShellSheetView.padding);
}

Finder _inHeader(Finder matching) => find.descendant(of: find.byType(ShellSheetHeader), matching: matching);

void main() {
  testOnMac('a top-level title starts on the content\'s left edge, and the close cross ends on its right edge', (
    tester,
  ) async {
    await _openSheet(tester, ShellSheet.settings);
    final edges = _contentEdges(tester);

    expect(tester.getRect(_inHeader(find.text('Settings'))).left, moreOrLessEquals(edges.left, epsilon: 1));
    expect(tester.getRect(find.byKey(ShellSheetHeader.closeGlyphKey)).right, moreOrLessEquals(edges.right, epsilon: 1));
  });

  testOnMac('with a parent the title is the path, starting on the content\'s edge, with no back arrow', (tester) async {
    await _openRecoveryPhraseStep(tester);
    final edges = _contentEdges(tester);

    final parent = tester.getRect(_inHeader(find.text('Settings')));
    final separator = tester.getRect(_inHeader(find.byIcon(CupertinoIcons.chevron_forward)));
    final title = tester.getRect(_inHeader(find.text('Recovery Phrase')));
    expect(parent.left, moreOrLessEquals(edges.left, epsilon: 1));
    expect(separator.left, greaterThan(parent.right));
    expect(title.left, greaterThan(separator.right));
    expect(_inHeader(find.byIcon(CupertinoIcons.chevron_back)), findsNothing);
    expect(tester.getRect(find.byKey(ShellSheetHeader.closeGlyphKey)).right, moreOrLessEquals(edges.right, epsilon: 1));
  });

  testOnMac('on a step the whole path is small and dim, one size, one colour, one baseline, below a top title', (
    tester,
  ) async {
    TextStyle styleOf(Finder text) =>
        tester.widget<RichText>(find.descendant(of: text, matching: find.byType(RichText))).text.style!;
    double baseline(Finder text) {
      final box = tester.renderObject<RenderBox>(find.descendant(of: text, matching: find.byType(RichText)));
      return box.localToGlobal(Offset(0, box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!)).dy;
    }

    await _openSheet(tester, ShellSheet.settings);
    final topTitle = styleOf(_inHeader(find.text('Settings')));

    await tester.tap(find.byKey(SettingsSheet.recoveryPhraseRowKey));
    await tester.pumpAndSettle();

    final parent = _inHeader(find.text('Settings'));
    final step = _inHeader(find.text('Recovery Phrase'));
    expect(styleOf(step).fontSize, styleOf(parent).fontSize);
    expect(styleOf(step).color, styleOf(parent).color);
    expect(styleOf(step).fontSize, lessThan(topTitle.fontSize!));
    expect(styleOf(step).color, isNot(topTitle.color));
    expect(baseline(parent), moreOrLessEquals(baseline(step), epsilon: 0.5));
  });

  testOnMac('clicking the parent goes back', (tester) async {
    await _openRecoveryPhraseStep(tester);

    await tester.tap(find.byKey(ShellSheetHeader.backKey));
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsSheet.recoveryPhraseRowKey), findsOneWidget);
    expect(_inHeader(find.text('Recovery Phrase')), findsNothing);
  });

  testOnMac('Tab reaches the parent, and Space goes back', (tester) async {
    await _openRecoveryPhraseStep(tester);

    var reached = false;
    for (var i = 0; i < 12 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      reached =
          focused != null &&
          find
              .descendant(of: find.byKey(ShellSheetHeader.backKey), matching: find.byWidget(focused.widget))
              .evaluate()
              .isNotEmpty;
    }
    expect(reached, isTrue, reason: 'Tab never reached the parent');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsSheet.recoveryPhraseRowKey), findsOneWidget);
  });

  testOnMac('a screen reader finds the parent as a Back button named for where it goes, and can press it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _openRecoveryPhraseStep(tester);

    final node = tester.getSemantics(find.byKey(ShellSheetHeader.backKey));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.label, 'Settings');
    expect(data.hint, 'Back');

    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsSheet.recoveryPhraseRowKey), findsOneWidget);
    semantics.dispose();
  });

  testOnMac('with an account, the title starts on the content\'s edge, the account follows, and the cross ends it', (
    tester,
  ) async {
    await _openSheet(tester, ShellSheet.receive);
    final edges = _contentEdges(tester);

    final title = tester.getRect(_inHeader(find.text('Receive')));
    final badge = tester.getRect(_inHeader(find.byType(DesktopAccountBadge)));
    final name = tester.getRect(_inHeader(find.text('Main')));
    expect(badge.size, const Size.square(24));
    expect(title.left, moreOrLessEquals(edges.left, epsilon: 1));
    // Right after the title, not pushed along the row.
    expect(badge.left - title.right, moreOrLessEquals(14, epsilon: 0.5));
    expect(name.left - badge.right, moreOrLessEquals(8, epsilon: 0.5));
    expect(tester.getRect(find.byKey(ShellSheetHeader.closeGlyphKey)).right, moreOrLessEquals(edges.right, epsilon: 1));
  });
}
