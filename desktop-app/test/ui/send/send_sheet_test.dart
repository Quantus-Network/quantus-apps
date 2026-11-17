import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
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
  await tester.tap(_toolbarSend());
  await tester.pumpAndSettle();
  return chain;
}

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

/// Answers the app's reads of the clipboard with [text].
void _putOnClipboard(WidgetTester tester, String text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': text};
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
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

    testOnMac('Send is dimmed on the Encrypted account, in the toolbar and the Account menu alike', (tester) async {
      await pumpOn(tester, encryptedAccount);

      expect(sendAction(tester).isEnabled, isFalse);
      expect(tester.widget<ToolbarAction>(_toolbarSend()).onPressed, isNull);
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
    });

    testOnMac('lists the four addresses paid last, never its own, each by its checkphrase', (tester) async {
      final chain = FakeSendChain()..recents = ['qzAda', 'qzMain', 'qzBo', 'qzCy', 'qzDee', 'qzEve'];

      await _openSend(tester, chain: chain);

      expect(_inSheet(find.text('RECENTS')), findsOneWidget);
      for (final address in ['qzAda', 'qzBo', 'qzCy', 'qzDee']) {
        expect(
          find.descendant(of: find.byKey(SendSheet.recentKey(address)), matching: find.text('Phrase-$address')),
          findsOneWidget,
        );
      }
      expect(find.byKey(SendSheet.recentKey('qzMain')), findsNothing);
      expect(find.byKey(SendSheet.recentKey('qzEve')), findsNothing);
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

    testOnMac('Max fills in the balance less the fee of sending everything, and follows that fee', (tester) async {
      final chain = await _openSend(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');
      final sendingAll = Completer<BigInt>();
      chain.fee = () => sendingAll.future;

      await tester.tap(find.byKey(SendSheet.maxKey));
      await tester.pump();

      expect(_typed(tester, SendSheet.amountFieldKey), '1249.9988');
      expect(chain.quotes.last, (recipient: 'qzPayee', amount: null));

      sendingAll.complete(_qtc(0.002));
      await tester.pump();
      await tester.pump();

      expect(_typed(tester, SendSheet.amountFieldKey), '1249.998');
      expect(_inSheet(find.text('0.002 QTC')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
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
      expect(tester.widget<ToolbarAction>(find.byKey(SendSheet.maxKey)).onPressed, isNull);
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
      expect(_inSheet(find.text('Phrase-qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
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
      await _tap(tester, SendSheet.maxKey);
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
      expect(_inSheet(find.text('Phrase-qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
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
