import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/utils/account_actions.dart';

import '../../fakes.dart';

/// [tokens] in the chain's smallest unit; ten-thousandths of a token are exact.
BigInt _qtc(num tokens) => BigInt.from((tokens * 10000).round()) * oneToken ~/ BigInt.from(10000);

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

/// That [address] stands in the sheet with its checkphrase right under it.
void _expectAddressOverCheckphrase(WidgetTester tester, String address, {Finder? within}) {
  Finder inside(Finder matching) =>
      within == null ? _inSheet(matching) : find.descendant(of: within, matching: matching);
  final addressRect = tester.getRect(inside(find.text(address)));
  final phraseRect = tester.getRect(inside(find.text('Phrase-$address')));
  expect(phraseRect.top, greaterThanOrEqualTo(addressRect.bottom));
  expect(phraseRect.top - addressRect.bottom, lessThan(8));
  expect(phraseRect.left, addressRect.left);
}

/// The URLs handed to the browser.
final _opened = <Uri>[];

/// Opens the wallet on [active], holding [balance] tokens, and presses Send
/// in the toolbar.
Future<FakeSendChain> _openSend(
  WidgetTester tester, {
  FakeSendChain? chain,
  FakeUserApproval? approval,
  num balance = 1250,
  Future<BigInt> Function(String accountId)? balanceOf,
  Size? window,
}) async {
  _opened.clear();
  chain ??= FakeSendChain();
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, savingsAccount, encryptedAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: {'qzMain': _qtc(balance), 'qzSavings': oneToken},
        balanceOf: balanceOf,
        encryptedBalances: {0: oneToken},
        approval: approval,
        chain: chain,
      ),
      openExternalUrlProvider.overrideWithValue((url) async => _opened.add(url)),
    ],
  );
  if (window != null) {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
  }
  await tester.tap(_toolbarSend());
  await tester.pumpAndSettle();
  return chain;
}

/// Four addresses of a real one's length, as the form lists them.
final _fourRecents = [
  for (final letter in ['A', 'B', 'C', 'D']) 'qz${letter * 44}',
];

/// The smallest window the app's runners allow.
const _smallestWindow = Size(960, 640);

ScrollableState _recentsScroll(WidgetTester tester) => tester.state<ScrollableState>(
  find.descendant(of: find.byKey(SendSheet.recentsKey), matching: find.byType(Scrollable)),
);

Future<void> _type(WidgetTester tester, Key field, String text) async {
  await tester.enterText(_editable(field), text);
  await tester.pump();
}

/// Past the pause a typed amount waits before its fee is asked for, and the
/// answer.
Future<void> _pastFeePause(WidgetTester tester) async {
  await tester.pump(SendFeeNotifier.debounce);
  await tester.pump();
}

/// Fills the form with a payment of [amount] to [recipient] and waits for
/// its fee.
Future<void> _fill(WidgetTester tester, {String recipient = 'qzPayee', String amount = '250'}) async {
  await _type(tester, SendSheet.addressFieldKey, recipient);
  await _type(tester, SendSheet.amountFieldKey, amount);
  await _pastFeePause(tester);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _toReview(WidgetTester tester, {String recipient = 'qzPayee', String amount = '250'}) async {
  await _fill(tester, recipient: recipient, amount: amount);
  await _tap(tester, SendSheet.reviewKey);
}

/// The box of the checkbox that sends the maximum.
Finder _maxBox() => find.descendant(of: find.byKey(SendSheet.maxKey), matching: find.byType(Checkbox));

bool _maxTicked(WidgetTester tester) => tester.widget<DesktopCheckbox>(find.byKey(SendSheet.maxKey)).value;

/// Whether the amount field can be typed in: locked, it is drawn at half
/// strength, takes no typing and is out of the keyboard's reach.
bool _amountLocked(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.descendant(of: find.byKey(SendSheet.amountFieldKey), matching: find.byType(TextField)),
  );
  final editable = tester.widget<EditableText>(_editable(SendSheet.amountFieldKey));
  final strength = tester
      .widget<Opacity>(find.descendant(of: find.byKey(SendSheet.amountFieldKey), matching: find.byType(Opacity)).first)
      .opacity;
  final locked = field.enabled == false;
  expect(editable.readOnly, locked);
  expect(editable.focusNode.canRequestFocus, !locked);
  expect(strength, locked ? 0.5 : 1);
  return locked;
}

/// Answers the app's reads of the clipboard with [text].
void _putOnClipboard(WidgetTester tester, String text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': text};
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

/// Holds the app's reads of the clipboard until the returned completer is
/// given the text they answer with.
Completer<String> _holdClipboard(WidgetTester tester) {
  final held = Completer<String>();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': await held.future};
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return held;
}

void main() {
  group('availability', () {
    Future<void> pumpOn(WidgetTester tester, Account active) => pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, encryptedAccount, vaultAccount],
        settings: FakeSettingsService(activeAccount: RegularAccount(active)),
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
      ),
    );

    AccountAction sendAction(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(DesktopShell)),
    ).read(activeAccountActionsProvider).singleWhere((action) => action.kind == AccountActionKind.send);

    testOnMac('Send can be used on a transparent account', (tester) async {
      await pumpOn(tester, mainAccount);

      expect(sendAction(tester).isEnabled, isTrue);
      expect(tester.widget<ToolbarAction>(_toolbarSend()).onPressed, isNotNull);
    });

    testOnMac('Send can be used on the Encrypted account, in the toolbar and the Account menu alike', (tester) async {
      await pumpOn(tester, encryptedAccount);

      expect(sendAction(tester).isEnabled, isTrue);
      expect(tester.widget<ToolbarAction>(_toolbarSend()).onPressed, isNotNull);
    });

    testOnMac('Send is dimmed on an account that signs on a hardware wallet', (tester) async {
      await pumpOn(tester, vaultAccount);

      expect(sendAction(tester).isEnabled, isFalse);
    });
  });

  group('the form', () {
    testOnMac('opens titled Send for the account, the address field ready for typing, Review unavailable', (
      tester,
    ) async {
      await _openSend(tester);

      expect(_inSheet(find.text('Send')), findsOneWidget);
      expect(_inSheet(find.text('Main')), findsOneWidget);
      expect(tester.widget<EditableText>(_editable(SendSheet.addressFieldKey)).focusNode.hasFocus, isTrue);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
      expect(_inSheet(find.text('RECENTS')), findsNothing);
      // What only a private send has.
      expect(find.byKey(SendSheet.privateNoticeKey), findsNothing);
      expect(_inSheet(find.text('Pending')), findsNothing);
      expect(_inSheet(find.text('Network fee')), findsOneWidget);
    });

    testOnMac('lists the four addresses paid last, never its own, each whole over its checkphrase', (tester) async {
      const long = 'qzpK3wXs9DfL2mVb7NcQ8rTy4HgJ6aZe1UoBi5WnRk7tYe';
      final chain = FakeSendChain()..recents = [long, 'qzMain', 'qzBo', 'qzCy', 'qzDee', 'qzEve'];

      await _openSend(tester, chain: chain);

      expect(_inSheet(find.text('RECENTS')), findsOneWidget);
      for (final address in [long, 'qzBo', 'qzCy', 'qzDee']) {
        _expectAddressOverCheckphrase(tester, address, within: find.byKey(SendSheet.recentKey(address)));
      }
      expect(find.byKey(SendSheet.recentKey('qzMain')), findsNothing);
      expect(find.byKey(SendSheet.recentKey('qzEve')), findsNothing);
    });

    testOnMac('in the smallest window, four addresses paid before leave the form whole and its buttons in reach', (
      tester,
    ) async {
      await _openSend(tester, chain: FakeSendChain()..recents = _fourRecents, window: _smallestWindow);

      final sheet = tester.getRect(find.byType(ShellSheetView));
      expect(sheet.bottom, lessThanOrEqualTo(_smallestWindow.height));
      expect(tester.getRect(find.byKey(SendSheet.reviewKey)).bottom, lessThan(sheet.bottom));
      expect(tester.getRect(find.byKey(SendSheet.maxKey)).bottom, lessThan(sheet.bottom));

      await _tap(tester, SendSheet.cancelKey);

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('in the smallest window, the list of addresses paid before scrolls to the last, which can be picked', (
      tester,
    ) async {
      await _openSend(tester, chain: FakeSendChain()..recents = _fourRecents, window: _smallestWindow);
      expect(_recentsScroll(tester).position.maxScrollExtent, greaterThan(0));

      expect(find.byKey(SendSheet.recentKey(_fourRecents.last)).hitTestable(), findsNothing);

      // The mouse's wheel, turned over the list as far as it goes.
      final wheel = TestPointer(1, PointerDeviceKind.mouse)..hover(tester.getCenter(find.byKey(SendSheet.recentsKey)));
      await tester.sendEventToBinding(wheel.scroll(Offset(0, _recentsScroll(tester).position.maxScrollExtent)));
      await tester.pumpAndSettle();
      await _tap(tester, SendSheet.recentKey(_fourRecents.last));

      expect(_typed(tester, SendSheet.addressFieldKey), _fourRecents.last);
    });

    testOnMac('in a window with room, all four addresses paid before show and the list does not scroll', (
      tester,
    ) async {
      await _openSend(tester, chain: FakeSendChain()..recents = _fourRecents);

      expect(_recentsScroll(tester).position.maxScrollExtent, 0);
      for (final address in _fourRecents) {
        expect(find.byKey(SendSheet.recentKey(address)).hitTestable(), findsOneWidget);
      }
    });

    testOnMac('a click on an address paid before fills the field, and the list makes way', (tester) async {
      await _openSend(tester, chain: FakeSendChain()..recents = ['qzAda', 'qzBo']);

      await _tap(tester, SendSheet.recentKey('qzBo'));

      expect(_typed(tester, SendSheet.addressFieldKey), 'qzBo');
      expect(_inSheet(find.text('RECENTS')), findsNothing);
      expect(find.byKey(SendSheet.recentKey('qzAda')), findsNothing);
    });

    testOnMac('Paste fills the address from the clipboard', (tester) async {
      _putOnClipboard(tester, '  qzPasted \n');
      await _openSend(tester);

      await _tap(tester, SendSheet.pasteKey);

      expect(_typed(tester, SendSheet.addressFieldKey), 'qzPasted');
    });

    testOnMac('Review does not open on an address the form has not accepted, even before it is drawn again', (
      tester,
    ) async {
      final clipboard = _holdClipboard(tester);
      await _openSend(tester);
      await _fill(tester);
      await tester.tap(find.byKey(SendSheet.pasteKey));
      await tester.pump();

      // The account's own address lands, and Review is pressed before a
      // frame has shown it refused.
      clipboard.complete('qzMain');
      await tester.idle();
      await tester.tap(find.byKey(SendSheet.reviewKey));
      await tester.pumpAndSettle();

      expect(find.byKey(SendSheet.sendKey), findsNothing);
      expect(_typed(tester, SendSheet.addressFieldKey), 'qzMain');
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('a valid address shows its checkphrase under the field', (tester) async {
      await _openSend(tester);

      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('CHECKPHRASE')), findsOneWidget);
      expect(_inSheet(find.text('Phrase-qzPayee')), findsOneWidget);
    });

    testOnMac('what is not an address is said to be none, and cannot be reviewed', (tester) async {
      await _openSend(tester);

      await _fill(tester, recipient: 'not an address');

      expect(_inSheet(find.text('This is not a Quantus address.')), findsOneWidget);
      expect(_inSheet(find.text('CHECKPHRASE')), findsNothing);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('the account\'s own address is refused', (tester) async {
      await _openSend(tester);

      await _fill(tester, recipient: 'qzMain');

      expect(_inSheet(find.text('You can’t send to the account you’re sending from.')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('shows what can be spent, and the network fee as an estimate until it is exact', (tester) async {
      await _openSend(tester);

      expect(_inSheet(find.text('1,250 QTC')), findsOneWidget);
      expect(_inSheet(find.text('~0.0012 QTC')), findsOneWidget);

      await _fill(tester);

      expect(_inSheet(find.text('0.0012 QTC')), findsOneWidget);
      expect(_inSheet(find.text('~0.0012 QTC')), findsNothing);
    });

    testOnMac('a typed amount is priced once the typing pauses', (tester) async {
      final chain = await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      final before = chain.quotes.length;

      await _type(tester, SendSheet.amountFieldKey, '2');
      await _type(tester, SendSheet.amountFieldKey, '25');
      await tester.pump(SendFeeNotifier.debounce - const Duration(milliseconds: 1));
      expect(chain.quotes, hasLength(before));

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(chain.quotes.sublist(before), [(recipient: 'qzPayee', amount: _qtc(25))]);
    });

    testOnMac('an amount is priced before there is an address to pay', (tester) async {
      final chain = await _openSend(tester);

      await _type(tester, SendSheet.amountFieldKey, '25');
      await _pastFeePause(tester);

      expect(chain.quotes.last, (recipient: 'qzMain', amount: _qtc(25)));
      expect(_inSheet(find.text('0.0012 QTC')), findsOneWidget);
    });

    testOnMac('more than can be sent is said under the field, with the most that can', (tester) async {
      await _openSend(tester);

      await _fill(tester, amount: '2000');

      expect(_inSheet(find.text('More than the 1,249.9988 QTC you can send.')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('less than the smallest send is said under the field', (tester) async {
      await _openSend(tester);

      await _fill(tester, amount: '0.001');

      expect(_inSheet(find.text('Minimum is 0.01 QTC')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('the maximum is a checkbox under the amount, unticked, and the label\'s line holds no Max', (
      tester,
    ) async {
      await _openSend(tester);

      final checkbox = tester.widget<DesktopCheckbox>(find.byKey(SendSheet.maxKey));
      expect(checkbox.label, 'Send the maximum amount');
      expect(checkbox.value, isFalse);
      final field = tester.getRect(find.byKey(SendSheet.amountFieldKey));
      final box = Rect.fromCenter(center: tester.getCenter(_maxBox()), width: Checkbox.width, height: Checkbox.width);
      expect(box.top, greaterThan(field.bottom));
      expect(box.left, field.left);
      expect(_inSheet(find.widgetWithText(ToolbarAction, 'Max')), findsNothing);
    });

    testOnMac('ticked, it fills in the balance less the fee of sending everything, and follows that fee', (
      tester,
    ) async {
      final chain = await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      final sendingAll = Completer<BigInt>();
      chain.fee = () => sendingAll.future;

      await tester.tap(_maxBox());
      await tester.pump();

      expect(_maxTicked(tester), isTrue);
      expect(_typed(tester, SendSheet.amountFieldKey), '1249.9988');
      expect(chain.quotes.last, (recipient: 'qzPayee', amount: null));

      sendingAll.complete(_qtc(0.002));
      await tester.pump();
      await tester.pump();

      expect(_amountLocked(tester), isTrue);
      expect(_typed(tester, SendSheet.amountFieldKey), '1249.998');
      expect(_inSheet(find.text('0.002 QTC')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    testOnMac('ticked, the amount is locked: a click does not give it the keyboard, and the tick stays', (
      tester,
    ) async {
      await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      expect(_amountLocked(tester), isFalse);

      await tester.tap(_maxBox());
      await tester.pumpAndSettle();
      expect(_amountLocked(tester), isTrue);

      await tester.tap(find.byKey(SendSheet.amountFieldKey), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(_editable(SendSheet.amountFieldKey)).focusNode.hasFocus, isFalse);
      expect(_typed(tester, SendSheet.amountFieldKey), '1249.9988');
      expect(_maxTicked(tester), isTrue);
    });

    testOnMac('Escape still closes the sheet while the amount is locked', (tester) async {
      await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      await tester.tap(_maxBox());
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('unticked, the amount can be typed again, and what is typed is priced and sent', (tester) async {
      final chain = await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      await tester.tap(_maxBox());
      await tester.pumpAndSettle();
      await tester.tap(_maxBox());
      await tester.pumpAndSettle();

      expect(_amountLocked(tester), isFalse);
      expect(_typed(tester, SendSheet.amountFieldKey), '1249.9988');

      await _type(tester, SendSheet.amountFieldKey, '5');
      await _pastFeePause(tester);

      expect(_maxTicked(tester), isFalse);
      expect(chain.quotes.last, (recipient: 'qzPayee', amount: _qtc(5)));

      await _tap(tester, SendSheet.reviewKey);
      await _tap(tester, SendSheet.sendKey);

      expect(chain.transfers.single.call, (recipient: 'qzPayee', amount: _qtc(5)));
    });

    testOnMac('unticked, the amount stays, is priced as itself and no longer follows the fee', (tester) async {
      final chain = await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      await tester.tap(_maxBox());
      await tester.pumpAndSettle();

      // Ticked, a fee this much dearer would lower the amount.
      chain.fee = () async => _qtc(0.002);
      await tester.tap(_maxBox());
      await tester.pumpAndSettle();

      expect(_maxTicked(tester), isFalse);
      expect(chain.quotes.last, (recipient: 'qzPayee', amount: _qtc(1249.9988)));
      expect(_inSheet(find.text('0.002 QTC')), findsOneWidget);
      expect(_typed(tester, SendSheet.amountFieldKey), '1249.9988');
    });

    testOnMac('a fee that cannot be had is said with Retry, which asks again', (tester) async {
      final chain = FakeSendChain()..fee = () async => throw StateError('offline');
      await _openSend(tester, chain: chain);
      await _fill(tester);

      expect(_inSheet(find.text('Unable to estimate fee')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);

      chain.fee = () async => FakeSendChain.usualFee;
      await _tap(tester, SendSheet.retryFeeKey);

      expect(_inSheet(find.text('Unable to estimate fee')), findsNothing);
      expect(_inSheet(find.text('0.0012 QTC')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    testOnMac('a balance that could not be read keeps Review unavailable without claiming a shortfall', (tester) async {
      await _openSend(tester, balanceOf: (accountId) async => throw StateError('offline'));

      await _fill(tester);

      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
      expect(_inSheet(find.textContaining('More than')), findsNothing);
      expect(tester.widget<DesktopCheckbox>(find.byKey(SendSheet.maxKey)).onChanged, isNull);
    });

    testOnMac('where nothing can approve a send, the form says what to set up and Review is unavailable', (
      tester,
    ) async {
      await _openSend(tester, approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp);

      await _fill(tester);

      expect(_inSheet(find.text('Set up a login password for this Mac to use this.')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('a filled form can be reviewed, with Enter in the amount field too', (tester) async {
      await _openSend(tester);
      await _fill(tester);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byKey(SendSheet.sendKey), findsOneWidget);
    });

    testOnMac('Cancel closes the sheet', (tester) async {
      await _openSend(tester);

      await _tap(tester, SendSheet.cancelKey);

      expect(find.byType(ShellSheetView), findsNothing);
    });
  });

  group('the review', () {
    testOnMac('shows the way back, the amount, who is paid in full, and what it costs', (tester) async {
      await _openSend(tester);

      await _toReview(tester);

      expect(find.descendant(of: find.byKey(ShellSheetHeader.backKey), matching: find.text('Send')), findsOneWidget);
      expect(_inSheet(find.text('Review')), findsOneWidget);
      expect(_inSheet(find.text('SENDING')), findsOneWidget);
      expect(_inSheet(find.text('250')), findsOneWidget);
      _expectAddressOverCheckphrase(tester, 'qzPayee');
      expect(_inSheet(find.text('From')), findsOneWidget);
      expect(_inSheet(find.text('Main')), findsNWidgets(2));
      expect(_inSheet(find.text('Network fee')), findsOneWidget);
      expect(_inSheet(find.text('0.0012 QTC')), findsOneWidget);
      expect(_inSheet(find.text('You pay')), findsOneWidget);
      expect(_inSheet(find.text('250.0012 QTC')), findsOneWidget);
      expect(find.byKey(SendSheet.addressFieldKey), findsNothing);
    });

    for (final (way, goBack) in <(String, Future<void> Function(WidgetTester))>[
      ('Back', (tester) => _tap(tester, SendSheet.backKey)),
      ('the path\'s Send', (tester) => _tap(tester, ShellSheetHeader.backKey)),
      (
        'Command-[',
        (tester) async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
          await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
          await tester.pumpAndSettle();
        },
      ),
    ]) {
      testOnMac('$way returns to the form as it was left', (tester) async {
        await _openSend(tester);
        await _toReview(tester);

        await goBack(tester);

        expect(find.byKey(SendSheet.sendKey), findsNothing);
        expect(_typed(tester, SendSheet.addressFieldKey), 'qzPayee');
        expect(_typed(tester, SendSheet.amountFieldKey), '250');
        expect(_canPress(tester, SendSheet.reviewKey), isTrue);
      });
    }

    testOnMac('back from the review, the keyboard is on the amount, or on the address when the amount is locked', (
      tester,
    ) async {
      bool focused(Key field) => tester.widget<EditableText>(_editable(field)).focusNode.hasFocus;
      await _openSend(tester);
      await _toReview(tester);

      await _tap(tester, SendSheet.backKey);
      expect(focused(SendSheet.amountFieldKey), isTrue);

      await tester.tap(_maxBox());
      await tester.pumpAndSettle();
      await _tap(tester, SendSheet.reviewKey);
      await _tap(tester, SendSheet.backKey);

      expect(focused(SendSheet.amountFieldKey), isFalse);
      expect(focused(SendSheet.addressFieldKey), isTrue);
    });

    testOnMac('a paste answered after the review opened does not change who is paid', (tester) async {
      final clipboard = _holdClipboard(tester);
      final chain = await _openSend(tester);
      await _fill(tester);
      await tester.tap(find.byKey(SendSheet.pasteKey));
      await tester.pump();
      await _tap(tester, SendSheet.reviewKey);

      // Send is pressed before a frame could show the late answer.
      clipboard.complete('qzOther');
      await tester.idle();
      await tester.tap(find.byKey(SendSheet.sendKey));
      await tester.pumpAndSettle();

      expect(chain.transfers.single.call, (recipient: 'qzPayee', amount: _qtc(250)));
      expect(_inSheet(find.text('SUBMITTED')), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('qzOther')), findsNothing);
    });

    testOnMac('a paste answered after the review opened cannot get the account\'s own address paid', (tester) async {
      final clipboard = _holdClipboard(tester);
      final chain = await _openSend(tester);
      await _fill(tester);
      await tester.tap(find.byKey(SendSheet.pasteKey));
      await tester.pump();
      await _tap(tester, SendSheet.reviewKey);

      clipboard.complete('qzMain');
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
      expect(_canPress(tester, SendSheet.sendKey), isTrue);

      await _tap(tester, SendSheet.sendKey);

      expect(chain.transfers.single.call, (recipient: 'qzPayee', amount: _qtc(250)));
    });

    testOnMac('a paste answered after the form was left is dropped, even once the form is back', (tester) async {
      final clipboard = _holdClipboard(tester);
      await _openSend(tester);
      await _fill(tester);
      await tester.tap(find.byKey(SendSheet.pasteKey));
      await tester.pump();
      await _tap(tester, SendSheet.reviewKey);
      await _tap(tester, SendSheet.backKey);

      clipboard.complete('qzOther');
      await tester.pumpAndSettle();

      expect(_typed(tester, SendSheet.addressFieldKey), 'qzPayee');
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    testOnMac('a send within one more fee of the balance waits for the fee of exactly its amount', (tester) async {
      final chain = await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      final exact = Completer<BigInt>();
      chain.fee = () => exact.future;
      await _type(tester, SendSheet.amountFieldKey, '1249.998');

      await tester.tap(find.byKey(SendSheet.reviewKey));
      await tester.pump();
      await tester.pump();

      expect(chain.quotes.last, (recipient: 'qzPayee', amount: _qtc(1249.998)));
      expect(_canPress(tester, SendSheet.sendKey), isFalse);
      expect(_inSheet(find.text('~0.0012 QTC')), findsOneWidget);

      exact.complete(FakeSendChain.usualFee);
      await tester.pump();
      await tester.pump();

      expect(_canPress(tester, SendSheet.sendKey), isTrue);
      expect(_inSheet(find.text('0.0012 QTC')), findsOneWidget);
    });

    testOnMac('Send asks for approval with the send\'s reason, then pays from the account the sheet opened on', (
      tester,
    ) async {
      final approval = FakeUserApproval();
      final chain = await _openSend(tester, approval: approval);
      await _toReview(tester);

      await _tap(tester, SendSheet.sendKey);

      expect(approval.reasons, ['Authenticate to confirm transaction']);
      expect(chain.transfers, [
        (
          from: 'qzMain',
          call: (recipient: 'qzPayee', amount: _qtc(250)),
          amount: _qtc(250),
          fee: FakeSendChain.usualFee,
        ),
      ]);
    });

    testOnMac('while a send is under way Send turns, Back is dimmed and nothing closes the sheet', (tester) async {
      final asked = Completer<ApprovalResult>();
      final chain = await _openSend(tester, approval: FakeUserApproval()..answer = () => asked.future);
      await _toReview(tester);

      await tester.tap(find.byKey(SendSheet.sendKey));
      await tester.pump();

      expect(_button(tester, SendSheet.sendKey).isLoading, isTrue);
      expect(_button(tester, SendSheet.backKey).isDisabled, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.byKey(ShellSheetHeader.closeGlyphKey));
      await tester.pump();
      await tester.tapAt(const Offset(1190, 790));
      await tester.pump();
      await tester.tap(find.byKey(ShellSheetHeader.backKey));
      await tester.pump();

      expect(find.byKey(SendSheet.sendKey), findsOneWidget);
      expect(chain.transfers, isEmpty);

      asked.complete(ApprovalResult.approved);
      await tester.pumpAndSettle();

      expect(chain.transfers, hasLength(1));
      expect(find.byKey(SendSheet.doneKey), findsOneWidget);
    });

    testOnMac('a declined approval sends nothing and says so beside the buttons; Send can be pressed again', (
      tester,
    ) async {
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.declined;
      final chain = await _openSend(tester, approval: approval);
      await _toReview(tester);

      await _tap(tester, SendSheet.sendKey);

      expect(_inSheet(find.text('Authentication required to send')), findsOneWidget);
      expect(chain.transfers, isEmpty);
      expect(_canPress(tester, SendSheet.sendKey), isTrue);
      expect(_canPress(tester, SendSheet.backKey), isTrue);

      approval.answer = () async => ApprovalResult.approved;
      await _tap(tester, SendSheet.sendKey);

      expect(chain.transfers, hasLength(1));
      expect(_inSheet(find.text('Authentication required to send')), findsNothing);
    });

    testOnMac('a send the network refuses is said beside the buttons', (tester) async {
      final chain = FakeSendChain()..submit = () async => throw StateError('offline');
      await _openSend(tester, chain: chain);
      await _toReview(tester);

      await _tap(tester, SendSheet.sendKey);

      expect(_inSheet(find.text('Failed submitting transaction')), findsOneWidget);
      expect(find.byKey(SendSheet.doneKey), findsNothing);
      expect(_canPress(tester, SendSheet.backKey), isTrue);
    });

    testOnMac('a max send hands over a transfer of everything', (tester) async {
      final chain = await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      await tester.tap(_maxBox());
      await tester.pumpAndSettle();
      await _tap(tester, SendSheet.reviewKey);

      expect(_inSheet(find.text('1,249.9988')), findsOneWidget);
      expect(_inSheet(find.text('1,250 QTC')), findsOneWidget);

      await _tap(tester, SendSheet.sendKey);

      expect(chain.transfers.single.call, (recipient: 'qzPayee', amount: null));
      expect(chain.transfers.single.amount, _qtc(1249.9988));
    });
  });

  group('the receipt', () {
    Future<FakeSendChain> send(WidgetTester tester) async {
      final chain = await _openSend(tester);
      await _toReview(tester);
      await _tap(tester, SendSheet.sendKey);
      return chain;
    }

    testOnMac('says the send was submitted, who was paid and what left the account, with no way back', (tester) async {
      await send(tester);

      expect(_inSheet(find.text('SUBMITTED')), findsOneWidget);
      expect(_inSheet(find.text('250 QTC sent')), findsOneWidget);
      expect(_inSheet(find.text('On its way')), findsOneWidget);
      _expectAddressOverCheckphrase(tester, 'qzPayee');
      expect(_inSheet(find.text('From')), findsOneWidget);
      expect(_inSheet(find.text('Network fee')), findsOneWidget);
      expect(_inSheet(find.text('0.0012 QTC')), findsOneWidget);
      expect(_inSheet(find.text('You paid')), findsOneWidget);
      expect(_inSheet(find.text('250.0012 QTC')), findsOneWidget);
      expect(_inSheet(find.text('You pay')), findsNothing);
      expect(find.byKey(ShellSheetHeader.backKey), findsNothing);
      expect(find.byKey(SendSheet.backKey), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('SUBMITTED')), findsOneWidget);
    });

    testOnMac('View in Explorer opens the transaction in the browser', (tester) async {
      await send(tester);

      await _tap(tester, SendSheet.explorerKey);

      expect(_opened, [Uri.parse('${AppConstants.explorerEndpoint}/transactions/0xhash')]);
    });

    testOnMac('Done closes the sheet, and Send opens empty again with a fresh fee', (tester) async {
      final chain = await send(tester);

      await _tap(tester, SendSheet.doneKey);
      expect(find.byType(ShellSheetView), findsNothing);

      final before = chain.quotes.length;
      await tester.tap(_toolbarSend());
      await tester.pumpAndSettle();

      expect(_typed(tester, SendSheet.addressFieldKey), isEmpty);
      expect(_typed(tester, SendSheet.amountFieldKey), isEmpty);
      expect(chain.quotes.sublist(before), [(recipient: 'qzMain', amount: oneToken)]);
    });
  });
}
