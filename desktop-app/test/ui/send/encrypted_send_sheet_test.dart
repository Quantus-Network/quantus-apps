import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
const _colors = AppColorsV3.dark();

BigInt _qtc(int tokens) => oneToken * BigInt.from(tokens);

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder _toolbarSend() =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Send'));

Finder _editable(Key field) => find.descendant(of: find.byKey(field), matching: find.byType(EditableText));

String _typed(WidgetTester tester, Key field) => tester.widget<EditableText>(_editable(field)).controller.text;

SheetButton _button(WidgetTester tester, Key key) => tester.widget<SheetButton>(find.byKey(key));

bool _canPress(WidgetTester tester, Key key) {
  final button = _button(tester, key);
  return !button.isDisabled && !button.isLoading;
}

Future<void> _type(WidgetTester tester, Key field, String text) async {
  await tester.enterText(_editable(field), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Fills the form with a payment of [amount] to [recipient]; the lookups of
/// the address and the fee have answered.
Future<void> _fill(WidgetTester tester, {String recipient = 'qzPayee', String amount = '250'}) async {
  await _type(tester, SendSheet.addressFieldKey, recipient);
  await _type(tester, SendSheet.amountFieldKey, amount);
  await tester.pump(SendFeeNotifier.debounce);
  await tester.pumpAndSettle();
}

TerminalLine _line(WidgetTester tester, int step) => tester.widget<TerminalLine>(find.byKey(SendSheet.stepKey(step)));

ClaimProgressItem _progress(int step, int completed, int total) =>
    ClaimProgressItem(step: step, title: 'step $step', completed: completed, total: total);

/// A private send part of the way: prepared, its proofs generated, the
/// third of eight privacy proofs being built.
EncryptedSendState _partWay(EncryptedSendPhase phase, {String? errorMessage, BigInt? submitted}) => EncryptedSendState(
  phase: phase,
  currentStep: 5,
  stepProgress: {4: _progress(4, 8, 8), 5: _progress(5, 3, 8)},
  errorMessage: errorMessage,
  submittedRecipientToken: submitted,
);

/// Opens the wallet on the Encrypted account, holding one deposit of 1,250
/// tokens unless told otherwise, and presses Send in the toolbar.
Future<FakeEncryptedSendController> _openSend(
  WidgetTester tester, {
  List<int> deposits = const [1250],
  int pending = 0,
  Set<String> ownAddresses = const {},
  FakeOneClickService? oneClick,
  FakeUserApproval? approval,
  Size? window,
}) async {
  final proving = FakeEncryptedSendController();
  await pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: const [mainAccount, encryptedAccount],
      settings: FakeSettingsService(activeAccount: const RegularAccount(encryptedAccount)),
      balances: {'qzMain': oneToken},
      encryptedStates: {0: encryptedHolding(deposits, pending: pending)},
      ownEncryptedAddresses: ownAddresses,
      oneClick: oneClick,
      approval: approval,
      proving: proving,
    ),
  );
  if (window != null) {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
  }
  await tester.tap(_toolbarSend());
  await tester.pumpAndSettle();
  return proving;
}

/// Fills the form, reviews and presses Send: the proving has been started.
Future<FakeEncryptedSendController> _startSend(WidgetTester tester, {Size? window}) async {
  final proving = await _openSend(tester, window: window);
  await _fill(tester);
  await _tap(tester, SendSheet.reviewKey);
  await _tap(tester, SendSheet.sendKey);
  return proving;
}

Future<void> _report(WidgetTester tester, FakeEncryptedSendController proving, EncryptedSendState state) async {
  proving.report(state);
  await tester.pumpAndSettle();
}

void main() {
  group('the form', () {
    testOnMac('opens titled Send for the Encrypted account and says the send is private', (tester) async {
      await _openSend(tester);

      expect(_inSheet(find.text('Send')), findsOneWidget);
      expect(_inSheet(find.text('Encrypted Account')), findsOneWidget);
      final notice = find.byKey(SendSheet.privateNoticeKey);
      expect(find.descendant(of: notice, matching: find.textContaining('Private Send', findRichText: true)), findsOne);
      expect(
        find.descendant(
          of: notice,
          matching: find.textContaining('Hides the link between your account and the recipient', findRichText: true),
        ),
        findsOne,
      );
    });

    testOnMac('in the smallest window the form is whole, its buttons in reach', (tester) async {
      const smallestWindow = Size(960, 640);
      await _openSend(tester, pending: 12, window: smallestWindow);
      await _fill(tester);

      final sheet = tester.getRect(find.byType(ShellSheetView));
      expect(sheet.bottom, lessThanOrEqualTo(smallestWindow.height));
      expect(tester.getRect(find.byKey(SendSheet.reviewKey)).bottom, lessThan(sheet.bottom));
    });

    testOnMac('shows what can be spent, and what is pending beside it only when something is', (tester) async {
      await _openSend(tester, pending: 12);

      expect(_inSheet(find.text('1,250 QTC')), findsOneWidget);
      expect(_inSheet(find.text('Pending')), findsOneWidget);
      expect(_inSheet(find.text('12 QTC')), findsOneWidget);
    });

    testOnMac('says nothing of pending when nothing is', (tester) async {
      await _openSend(tester);

      expect(_inSheet(find.text('Pending')), findsNothing);
    });

    testOnMac('what the send costs is called the transaction fee', (tester) async {
      await _openSend(tester);
      await _fill(tester);

      expect(_inSheet(find.text('Transaction fee')), findsOneWidget);
      expect(_inSheet(find.text('Network fee')), findsNothing);
      expect(_inSheet(find.text('0.5 QTC')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    for (final (what, address) in [
      ('the account\'s address', 'qzEncrypted'),
      ('an address it derived', 'qzOwnChange'),
    ]) {
      testOnMac('$what is refused as its own', (tester) async {
        await _openSend(tester, ownAddresses: {'qzOwnChange'});

        await _fill(tester, recipient: address);

        expect(_inSheet(find.text('You can’t send to the account you’re sending from.')), findsOneWidget);
        expect(_canPress(tester, SendSheet.reviewKey), isFalse);
      });
    }

    testOnMac('a single-use NEAR Intents deposit address is refused, with what to do instead', (tester) async {
      await _openSend(tester, oneClick: FakeOneClickService(deposits: {'qzDeposit'}));

      await _fill(tester, recipient: 'qzDeposit');

      expect(_inSheet(find.text(_l10n.encryptedSendNearIntentsDescription)), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('an amount that is not a whole step is said under the field', (tester) async {
      await _openSend(tester);

      await _fill(tester, amount: '250.005');

      expect(_inSheet(find.text('Use steps of 0.01 QTC')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('more than can be sent is said under the field, with the most that can', (tester) async {
      await _openSend(tester);

      await _fill(tester, amount: '2000');

      expect(_inSheet(find.text('More than the 1,249.5 QTC you can send.')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('the maximum is what the deposits leave once the fee is taken', (tester) async {
      await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');

      await tester.tap(find.descendant(of: find.byKey(SendSheet.maxKey), matching: find.byType(Checkbox)));
      await tester.pumpAndSettle();

      expect(tester.widget<DesktopCheckbox>(find.byKey(SendSheet.maxKey)).value, isTrue);
      expect(_typed(tester, SendSheet.amountFieldKey), '1249.5');
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });
  });

  group('the review', () {
    testOnMac('shows the amount, who is paid, the transaction fee and what leaves the account', (tester) async {
      await _openSend(tester);
      await _fill(tester);

      await _tap(tester, SendSheet.reviewKey);

      expect(_inSheet(find.text('250')), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('Phrase-qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('Encrypted Account')), findsNWidgets(2));
      expect(_inSheet(find.text('Transaction fee')), findsOneWidget);
      expect(_inSheet(find.text('0.5 QTC')), findsOneWidget);
      expect(_inSheet(find.text('You pay')), findsOneWidget);
      expect(_inSheet(find.text('250.5 QTC')), findsOneWidget);
    });

    testOnMac('Send asks for approval, then starts the proving once, with what was reviewed', (tester) async {
      final approval = FakeUserApproval();
      final proving = await _openSend(tester, approval: approval);
      await _fill(tester);
      await _tap(tester, SendSheet.reviewKey);

      await _tap(tester, SendSheet.sendKey);

      expect(approval.reasons, ['Authenticate to confirm transaction']);
      final start = proving.starts.single;
      expect(start.account, encryptedAccount);
      expect(start.amount, _qtc(250));
      expect(start.plan.amountToken, _qtc(250));
      expect(start.recipient, 'qzPayee');
      expect(find.byKey(SendSheet.sendKey), findsNothing);
      expect(find.byKey(SendSheet.stopKey), findsOneWidget);
    });

    testOnMac('a declined approval starts nothing and says so beside the buttons', (tester) async {
      final proving = await _openSend(
        tester,
        approval: FakeUserApproval()..answer = () async => ApprovalResult.declined,
      );
      await _fill(tester);
      await _tap(tester, SendSheet.reviewKey);

      await _tap(tester, SendSheet.sendKey);

      expect(_inSheet(find.text('Authentication required to send')), findsOneWidget);
      expect(proving.starts, isEmpty);
      expect(_canPress(tester, SendSheet.sendKey), isTrue);
    });
  });

  group('the progress', () {
    testOnMac('names the send: the amount, and the whole address over its checkphrase', (tester) async {
      await _startSend(tester);

      expect(_inSheet(find.text('SENDING PRIVATELY')), findsOneWidget);
      expect(_inSheet(find.text('250')), findsOneWidget);
      final address = tester.getRect(_inSheet(find.text('qzPayee')));
      final phrase = tester.getRect(_inSheet(find.text('Phrase-qzPayee')));
      expect(phrase.top, greaterThanOrEqualTo(address.bottom));
      expect(phrase.left, address.left);
    });

    testOnMac('each step is a line: done ones say OK, the running one its count, later ones wait dimmed', (
      tester,
    ) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, _partWay(EncryptedSendPhase.running));

      expect(_line(tester, 1).name, 'Preparing');
      expect(_line(tester, 1).status, '[OK]');
      expect(_line(tester, 1).statusColor, _colors.semanticSage);
      expect(_line(tester, 4).name, 'Generate proofs');
      expect(_line(tester, 4).status, '[OK]');
      expect(_line(tester, 5).name, 'Building privacy proof');
      expect(_line(tester, 5).status, '3/8');
      expect(_line(tester, 5).statusColor, _colors.accentFlare);
      expect(_line(tester, 5).isDim, isFalse);
      expect(_line(tester, 6).name, 'Submitting to chain');
      expect(_line(tester, 6).status, isNull);
      expect(_line(tester, 6).isDim, isTrue);
    });

    testOnMac('a step that runs without a count says that it runs', (tester) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, EncryptedSendState(phase: EncryptedSendPhase.running, currentStep: 1));

      expect(_line(tester, 1).status, '...');
      expect(_line(tester, 1).statusColor, _colors.accentFlare);
    });

    testOnMac('the proving is kept alive while the sheet shows it', (tester) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, _partWay(EncryptedSendPhase.running));
      await tester.pump(const Duration(seconds: 30));

      expect(proving.wasDisposed, isFalse);
    });

    testOnMac('while it runs it says to keep the app open, and nothing but Cancel leaves it', (tester) async {
      final proving = await _startSend(tester);
      await _report(tester, proving, _partWay(EncryptedSendPhase.running));

      expect(_inSheet(find.text(_l10n.encryptedSendProgressFooter)), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.byKey(ShellSheetHeader.closeGlyphKey));
      await tester.pump();
      await tester.tapAt(const Offset(1190, 790));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(find.byKey(SendSheet.stopKey), findsOneWidget);
      expect(find.byKey(ShellSheetHeader.backKey), findsNothing);
      expect(proving.cancels, 0);

      await tester.tap(find.byKey(SendSheet.stopKey));
      await tester.pump();

      expect(proving.cancels, 1);
      expect(_button(tester, SendSheet.stopKey).isDisabled, isTrue);
      expect(_inSheet(find.text('Canceling...')), findsOneWidget);
      expect(_inSheet(find.text(_l10n.encryptedSendProgressFooter)), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ShellSheetView), findsOneWidget);
    });

    testOnMac('cancelled before anything was sent: the line it stopped at says so, and the funds are safe', (
      tester,
    ) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, _partWay(EncryptedSendPhase.cancelled));

      expect(_inSheet(find.text('SEND CANCELLED')), findsOneWidget);
      expect(_line(tester, 4).status, '[OK]');
      expect(_line(tester, 5).status, '[STOPPED]');
      expect(_line(tester, 5).statusColor, _colors.semanticSand);
      expect(_line(tester, 6).status, isNull);
      expect(_inSheet(find.text('Your funds are safe')), findsOneWidget);
      expect(_inSheet(find.text('Still in Encrypted Account. Nothing left your wallet.')), findsOneWidget);
      expect(find.byKey(SendSheet.stopKey), findsNothing);

      await _tap(tester, SendSheet.closeKey);

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('cancelled after part was sent: it says how much went out', (tester) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, _partWay(EncryptedSendPhase.cancelled, submitted: _qtc(100)));

      expect(_inSheet(find.text(_l10n.encryptedSendCancelledPartial('100 QTC'))), findsOneWidget);
      expect(_inSheet(find.text('Your funds are safe')), findsNothing);
      expect(find.byKey(SendSheet.closeKey), findsOneWidget);
    });

    testOnMac('failed: the line it failed at says so, with what went wrong and no way to try again', (tester) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, _partWay(EncryptedSendPhase.failed, errorMessage: 'The network refused it'));

      expect(_inSheet(find.text('SEND FAILED')), findsOneWidget);
      expect(_line(tester, 5).status, '[FAILED]');
      expect(_line(tester, 5).statusColor, _colors.semanticEmber);
      expect(_inSheet(find.text('The network refused it')), findsOneWidget);
      expect(find.byKey(SendSheet.sendKey), findsNothing);
      expect(find.byKey(SendSheet.backKey), findsNothing);
      expect(find.byKey(ShellSheetHeader.backKey), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('in the smallest window, a failure however long leaves Close in the sheet', (tester) async {
      const smallestWindow = Size(960, 640);
      final proving = await _startSend(tester, window: smallestWindow);

      await _report(
        tester,
        proving,
        _partWay(EncryptedSendPhase.failed, errorMessage: 'The network refused it. ' * 60),
      );

      final sheet = tester.getRect(find.byType(ShellSheetView));
      expect(sheet.bottom, lessThanOrEqualTo(smallestWindow.height));
      expect(tester.getRect(find.byKey(SendSheet.closeKey)).bottom, lessThan(sheet.bottom));

      await _tap(tester, SendSheet.closeKey);

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('a balance that changed under the review fails the send before any step ran', (tester) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, EncryptedSendState(phase: EncryptedSendPhase.planStale));

      expect(_inSheet(find.text('SEND FAILED')), findsOneWidget);
      expect(_inSheet(find.text(_l10n.encryptedSendPlanStale)), findsOneWidget);
      for (final step in [1, 4, 5, 6]) {
        expect(_line(tester, step).status, isNull);
      }
      expect(find.byKey(SendSheet.closeKey), findsOneWidget);
    });
  });

  group('the receipt', () {
    testOnMac('says what was sent and what it cost, with no transaction to open in the explorer', (tester) async {
      final proving = await _startSend(tester);

      await _report(tester, proving, _partWay(EncryptedSendPhase.succeeded));

      expect(_inSheet(find.text('SUBMITTED')), findsOneWidget);
      expect(_inSheet(find.text('250 QTC sent')), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('Transaction fee')), findsOneWidget);
      expect(_inSheet(find.text('0.5 QTC')), findsOneWidget);
      expect(_inSheet(find.text('You paid')), findsOneWidget);
      expect(_inSheet(find.text('250.5 QTC')), findsOneWidget);
      expect(find.byKey(SendSheet.explorerKey), findsNothing);
      expect(find.byKey(SendSheet.stopKey), findsNothing);

      await _tap(tester, SendSheet.doneKey);

      expect(find.byType(ShellSheetView), findsNothing);
    });
  });
}
