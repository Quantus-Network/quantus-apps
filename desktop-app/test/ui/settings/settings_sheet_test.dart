import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/components/recovery_phrase_grid.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/boot_intro.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

/// A stored phrase whose words say where they are: `w01` … `w24`.
final _words = [for (var i = 1; i <= 24; i++) 'w${i.toString().padLeft(2, '0')}'];

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

/// Puts a wallet with [_words] (or [mnemonic]) on the device, then opens
/// Settings.
Future<FakeWalletDevice> _openSettings(
  WidgetTester tester, {
  FakeUserApproval? approval,
  FakeSensitiveClipboard? clipboard,
  String? mnemonic,
  bool storePhrase = true,
}) async {
  final device = FakeWalletDevice()..store([mainAccount], mnemonic: mnemonic ?? _words.join(' '));
  await pumpShell(
    tester,
    overrides: [
      ...device.overrides,
      userApprovalProvider.overrideWithValue(approval ?? FakeUserApproval()),
      sensitiveClipboardProvider.overrideWithValue(clipboard ?? FakeSensitiveClipboard()),
    ],
  );
  // The stored phrase was read at start; one left out is gone only now, so
  // the shell does not wipe the wallet before the test begins.
  if (!storePhrase) device.storage.mnemonics.clear();
  ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(shellSheetProvider.notifier).open(ShellSheet.settings);
  await tester.pumpAndSettle();
  return device;
}

/// Whether the Reset Wallet button can be pressed.
bool _resetEnabled(WidgetTester tester) {
  final button = tester.widget<QuantusButton>(
    find.descendant(of: find.byKey(SettingsSheet.resetButtonKey), matching: find.byType(QuantusButton)),
  );
  return button.onTap != null && !button.isDisabled && !button.isLoading;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _toPhraseWords(WidgetTester tester) async {
  await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
  await _tap(tester, find.byKey(SettingsSheet.continueKey));
}

/// Presses Tab until the keyboard's focus is inside [target].
Future<void> _tabTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 12; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null && find.descendant(of: target, matching: find.byWidget(focused.widget)).evaluate().isNotEmpty) {
      return;
    }
    if (focused != null && target.evaluate().any((e) => e.widget == focused.widget)) return;
  }
  fail('Tab never reached $target');
}

/// A test run as the Windows app.
void _testOnWindows(String description, WidgetTesterCallback body) =>
    testWidgets(description, body, variant: TargetPlatformVariant.only(TargetPlatform.windows));

/// A test run as the Linux app.
void _testOnLinux(String description, WidgetTesterCallback body) =>
    testWidgets(description, body, variant: TargetPlatformVariant.only(TargetPlatform.linux));

void main() {
  group('the list', () {
    testOnMac('has the wallet group and the preferences group, with the current language', (tester) async {
      await _openSettings(tester);

      expect(_inSheet(find.text('Settings')), findsOneWidget);
      expect(_inSheet(find.text('WALLET')), findsOneWidget);
      expect(_inSheet(find.text('Recovery Phrase')), findsOneWidget);
      expect(_inSheet(find.text('View your 24-word Backup Password')), findsOneWidget);
      expect(_inSheet(find.text('Reset Wallet')), findsOneWidget);
      expect(_inSheet(find.text('Removes all data from this device')), findsOneWidget);
      expect(_inSheet(find.text('PREFERENCES')), findsOneWidget);
      expect(_inSheet(find.text('Language')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(SettingsSheet.languageKey), matching: find.text('English')),
        findsOneWidget,
      );
    });

    testOnMac('choosing Bahasa Indonesia changes the app\'s language and keeps it, with the sheet left open', (
      tester,
    ) async {
      final device = await _openSettings(tester);

      await _tap(tester, find.byKey(SettingsSheet.languageKey));
      await _tap(tester, find.text('Bahasa Indonesia').last);

      expect(device.storage.locale, 'id');
      expect(_inSheet(find.text('Pengaturan')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(SettingsSheet.languageKey), matching: find.text('Bahasa Indonesia')),
        findsOneWidget,
      );
    });

    _testOnLinux('on Linux the wallet rows cannot be used yet and say why, while Language still works', (tester) async {
      final approval = FakeUserApproval()..availabilityAnswer = ApprovalAvailability.unsupported;
      final device = await _openSettings(tester, approval: approval);
      const note = 'Not available on Linux yet: it will ask for your login password.';

      expect(_inSheet(find.text(note)), findsNWidgets(2));

      await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
      await _tap(tester, find.byKey(SettingsSheet.resetRowKey));

      expect(_inSheet(find.text('WALLET')), findsOneWidget);
      expect(approval.reasons, isEmpty);

      await _tap(tester, find.byKey(SettingsSheet.languageKey));
      await _tap(tester, find.text('Bahasa Indonesia').last);

      expect(device.storage.locale, 'id');
    });

    testOnMac('on a Mac with no login password the wallet rows cannot be used and say what to set up', (tester) async {
      await _openSettings(tester, approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp);

      expect(_inSheet(find.text('Set up a login password for this Mac to use this.')), findsNWidgets(2));

      await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));

      expect(_inSheet(find.text('WALLET')), findsOneWidget);
    });

    _testOnWindows('on Windows without Windows Hello the wallet rows say to set it up', (tester) async {
      await _openSettings(tester, approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp);

      expect(_inSheet(find.text('Set up Windows Hello to use this.')), findsNWidgets(2));
    });

    testOnMac('Tab reaches a row and Space opens it', (tester) async {
      await _openSettings(tester);

      await _tabTo(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('Keep your Recovery Phrase Secret')), findsOneWidget);
    });

    testOnMac('a screen reader can open an available row, and not an unavailable one', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openSettings(tester);

      final node = tester.getSemantics(find.byKey(SettingsSheet.recoveryPhraseRowKey));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
      );
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('Keep your Recovery Phrase Secret')), findsOneWidget);
      semantics.dispose();
    });

    _testOnLinux('a screen reader finds an unavailable row disabled, with nothing to press', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openSettings(tester, approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.unsupported);

      final data = tester.getSemantics(find.byKey(SettingsSheet.recoveryPhraseRowKey)).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isEnabled, isNot(true));
      semantics.dispose();
    });
  });

  group('Recovery Phrase', () {
    testOnMac('opens on the caution; the Settings path and Cancel both return to the list', (tester) async {
      await _openSettings(tester);

      await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));

      expect(_inSheet(find.text('Recovery Phrase')), findsOneWidget);
      expect(_inSheet(find.text('BEFORE YOU LOOK')), findsOneWidget);
      expect(_inSheet(find.text('Keep your Recovery Phrase Secret')), findsOneWidget);
      for (final line in [
        'If you lose this device, your recovery phrase is the only way back',
        'Anyone who gets hold of it has complete control over your funds, permanently',
        'Write it down and keep it somewhere safe. Do not save it digitally',
      ]) {
        expect(_inSheet(find.text(line)), findsOneWidget);
      }

      await _tap(tester, find.byKey(ShellSheetHeader.backKey));

      expect(_inSheet(find.text('WALLET')), findsOneWidget);

      await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
      await _tap(tester, find.byKey(SettingsSheet.cancelKey));

      expect(_inSheet(find.text('WALLET')), findsOneWidget);
    });

    testOnMac(
      'Continue asks for approval, then shows the words masked, with Show ready, and records nothing seen yet',
      (tester) async {
        final approval = FakeUserApproval();
        final device = await _openSettings(tester, approval: approval);

        await _toPhraseWords(tester);

        expect(approval.reasons, ['Authenticate to see recovery phrase']);
        for (final word in _words) {
          expect(find.text(word), findsNothing);
        }
        expect(
          _inSheet(find.text(RecoveryPhraseGrid.maskedWord)),
          findsNWidgets(24),
          reason: 'one placeholder for every word, so no word\'s length shows',
        );
        expect(tester.widget<ToolbarAction>(find.byKey(SettingsSheet.hideKey)).label, 'Show');
        expect(device.storage.viewedPhrases, isEmpty);
      },
    );

    testOnMac('a declined approval stays on the caution, says approval is needed, and shows no word', (tester) async {
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.declined;
      final device = await _openSettings(tester, approval: approval);

      await _toPhraseWords(tester);

      expect(_inSheet(find.text('Keep your Recovery Phrase Secret')), findsOneWidget);
      expect(_inSheet(find.text('Authentication required to see recovery phrase')), findsOneWidget);
      expect(find.text('w01'), findsNothing);
      expect(device.storage.viewedPhrases, isEmpty);
    });

    testOnMac('an approval that finds nothing set up says what to set up', (tester) async {
      await _openSettings(tester, approval: FakeUserApproval()..answer = () async => ApprovalResult.notSetUp);

      await _toPhraseWords(tester);

      expect(_inSheet(find.text('Set up a login password for this Mac to use this.')), findsOneWidget);
      expect(find.text('w01'), findsNothing);
    });

    testOnMac('an approval prompt that fails says why', (tester) async {
      await _openSettings(tester, approval: FakeUserApproval()..answer = () async => throw Exception('no prompt'));

      await _toPhraseWords(tester);

      expect(_inSheet(find.text('Couldn’t ask for approval: Exception: no prompt')), findsOneWidget);
      expect(find.text('w01'), findsNothing);
    });

    testOnMac('Show reveals the words read down each column, records them seen, and Hide masks them again unasked', (
      tester,
    ) async {
      final approval = FakeUserApproval();
      final words = ['a', ..._words.skip(1)];
      final device = await _openSettings(tester, approval: approval, mnemonic: words.join(' '));
      await _toPhraseWords(tester);

      await _tap(tester, find.byKey(SettingsSheet.hideKey));

      for (final word in words) {
        expect(_inSheet(find.text(word)), findsOneWidget);
      }
      final first = tester.getCenter(find.text('a'));
      expect(tester.getCenter(find.text('w02')).dx, first.dx);
      expect(tester.getCenter(find.text('w02')).dy, greaterThan(first.dy));
      expect(tester.getCenter(find.text('w07')).dy, first.dy);
      expect(tester.getCenter(find.text('w07')).dx, greaterThan(first.dx));
      expect(device.storage.viewedPhrases, {0});
      expect(tester.widget<ToolbarAction>(find.byKey(SettingsSheet.hideKey)).label, 'Hide');

      await _tap(tester, find.byKey(SettingsSheet.hideKey));

      for (final word in words) {
        expect(find.text(word), findsNothing);
      }
      expect(_inSheet(find.text(RecoveryPhraseGrid.maskedWord)), findsNWidgets(24));
      expect(approval.reasons, hasLength(1));
    });

    testOnMac('Copy copies the phrase kept out of clipboard history, says Copied, and records it seen', (tester) async {
      final clipboard = FakeSensitiveClipboard();
      final device = await _openSettings(tester, clipboard: clipboard);
      await _toPhraseWords(tester);
      expect(device.storage.viewedPhrases, isEmpty);

      await tester.tap(find.byKey(SettingsSheet.copyKey));
      await tester.pump();

      expect(clipboard.copied, [_words.join(' ')]);
      expect(tester.widget<ToolbarAction>(find.byKey(SettingsSheet.copyKey)).label, 'Copied');
      expect(device.storage.viewedPhrases, {0});
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testOnMac('a copy that cannot be kept out of clipboard history says so, and is never made plainly', (tester) async {
      final systemClipboard = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method.startsWith('Clipboard.')) systemClipboard.add(call);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _openSettings(tester, clipboard: FakeSensitiveClipboard()..error = PlatformException(code: 'pasteboard'));
      await _toPhraseWords(tester);

      await _tap(tester, find.byKey(SettingsSheet.copyKey));

      expect(_inSheet(find.text('Couldn’t copy the recovery phrase.')), findsOneWidget);
      expect(tester.widget<ToolbarAction>(find.byKey(SettingsSheet.copyKey)).label, 'Copy');
      expect(systemClipboard, isEmpty);
    });

    testOnMac('Done closes the sheet', (tester) async {
      await _openSettings(tester);
      await _toPhraseWords(tester);

      await _tap(tester, find.byKey(SettingsSheet.doneKey));

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('a phrase that cannot be read says so and shows no words', (tester) async {
      await _openSettings(tester, storePhrase: false);

      await _toPhraseWords(tester);

      expect(_inSheet(find.text('This wallet’s recovery phrase could not be read.')), findsOneWidget);
      expect(find.byKey(SettingsSheet.phraseGridKey), findsNothing);
    });
  });

  testOnMac('on the words step, Hide starts on the content\'s left edge', (tester) async {
    await _openSettings(tester);
    await _toPhraseWords(tester);

    final sheet = tester.getRect(find.byType(ShellSheetView));
    final icon = find.descendant(of: find.byKey(SettingsSheet.hideKey), matching: find.byType(Icon));
    expect(tester.getRect(icon).left, moreOrLessEquals(sheet.left + ShellSheetView.padding, epsilon: 0.5));
  });

  group('keys', () {
    testOnMac('Command-[ on a step goes back to the list', (tester) async {
      await _openSettings(tester);
      await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsSheet.recoveryPhraseRowKey), findsOneWidget);
    });

    testOnWindowsAndLinux('Alt-Left on a step goes back to the list', (tester) async {
      await _openSettings(tester);
      await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsSheet.recoveryPhraseRowKey), findsOneWidget);
    });

    testOnMac('Command-[ on the list does nothing, and the sheet stays open', (tester) async {
      await _openSettings(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsOneWidget);
      expect(find.byKey(SettingsSheet.recoveryPhraseRowKey), findsOneWidget);
    });

    testOnMac('Escape on a step closes the whole sheet', (tester) async {
      await _openSettings(tester);
      await _tap(tester, find.byKey(SettingsSheet.resetRowKey));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });
  });

  group('Reset Wallet', () {
    testOnMac('shows the caution, and Reset Wallet is unavailable until the backup box is ticked', (tester) async {
      await _openSettings(tester);

      await _tap(tester, find.byKey(SettingsSheet.resetRowKey));

      expect(_inSheet(find.text('CANNOT BE UNDONE')), findsOneWidget);
      expect(_inSheet(find.text('This will erase your wallet')), findsOneWidget);
      for (final line in [
        'All wallet data will be permanently removed from this device',
        'Your funds stay on the blockchain but only your recovery phrase can restore access',
        'Without it, your funds are gone forever',
      ]) {
        expect(_inSheet(find.text(line)), findsOneWidget);
      }
      expect(_resetEnabled(tester), isFalse);

      await _tap(tester, find.text("I've backed up my recovery phrase"));

      expect(_resetEnabled(tester), isTrue);
    });

    testOnMac('Space ticks the backup box once Tab reaches it', (tester) async {
      await _openSettings(tester);
      await _tap(tester, find.byKey(SettingsSheet.resetRowKey));

      await _tabTo(tester, find.byKey(SettingsSheet.backupCheckboxKey));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(_resetEnabled(tester), isTrue);
    });

    testOnMac('once approved it wipes the wallet, closes the sheet and shows Welcome, without the boot intro', (
      tester,
    ) async {
      final approval = FakeUserApproval();
      final device = await _openSettings(tester, approval: approval);
      await _tap(tester, find.byKey(SettingsSheet.resetRowKey));
      await _tap(tester, find.text("I've backed up my recovery phrase"));

      await _tap(tester, find.byKey(SettingsSheet.resetButtonKey));

      expect(approval.reasons, ['Authenticate to reset wallet']);
      expect(device.logouts, 1);
      expect(device.storage.accounts, isEmpty);
      expect(find.byType(ShellSheetView), findsNothing);
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(BootIntro), findsNothing);
    });

    testOnMac('a declined approval wipes nothing and says approval is needed', (tester) async {
      final device = await _openSettings(
        tester,
        approval: FakeUserApproval()..answer = () async => ApprovalResult.declined,
      );
      await _tap(tester, find.byKey(SettingsSheet.resetRowKey));
      await _tap(tester, find.text("I've backed up my recovery phrase"));

      await _tap(tester, find.byKey(SettingsSheet.resetButtonKey));

      expect(device.logouts, 0);
      expect(_inSheet(find.text('Authentication required to reset wallet')), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
    });

    testOnMac('a wipe that fails says why and stays on the reset step', (tester) async {
      final device = await _openSettings(tester)
        ..logoutError = Exception('keychain locked');
      await _tap(tester, find.byKey(SettingsSheet.resetRowKey));
      await _tap(tester, find.text("I've backed up my recovery phrase"));

      await _tap(tester, find.byKey(SettingsSheet.resetButtonKey));

      expect(device.storage.accounts, isNotEmpty);
      expect(_inSheet(find.text('Failed to reset wallet: Exception: keychain locked')), findsOneWidget);
      expect(_inSheet(find.text('This will erase your wallet')), findsOneWidget);
    });
  });
}
