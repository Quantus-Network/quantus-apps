import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/send/send_summary.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

/// A multisig of three signers that needs two of them, of which Main, an
/// account of this wallet, is one.
final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzOther', 'qzThird'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

/// [tokens] in the chain's smallest unit; ten-thousandths of a token are exact.
BigInt _qtc(num tokens) => BigInt.from((tokens * 10000).round()) * oneToken ~/ BigInt.from(10000);

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder _toolbarPropose() =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Propose'));

Finder _editable(Key field) => find.descendant(of: find.byKey(field), matching: find.byType(EditableText));

String _typed(WidgetTester tester, Key field) => tester.widget<EditableText>(_editable(field)).controller.text;

bool _canPress(WidgetTester tester, Key key) {
  final button = tester.widget<SheetButton>(find.byKey(key));
  return !button.isDisabled && !button.isLoading;
}

/// The label of [account] on the same line as [text].
Finder _accountBeside(WidgetTester tester, String text, String account) {
  final line = tester.getCenter(_inSheet(find.text(text))).dy;
  return find.byElementPredicate((element) {
    final widget = element.widget;
    if (widget is! AccountLabel || widget.account.name != account) return false;
    final box = element.renderObject! as RenderBox;
    return (box.localToGlobal(box.size.center(Offset.zero)).dy - line).abs() <= 2;
  }, description: 'the label of $account beside "$text"');
}

/// The URLs handed to the browser.
final _opened = <Uri>[];

/// What was handed to the system's share picker.
final _shared = <String>[];

const _smallestWindow = Size(960, 640);

List<Override> _overrides({
  required MultisigAccount multisig,
  FakeSendChain? chain,
  FakeUserApproval? approval,
  num teamHolds = 4800,
  num mainHolds = 1250,
}) => [
  ...shellOverrides(
    accounts: const [mainAccount, savingsAccount, vaultAccount],
    settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(multisig), multisigs: [multisig]),
    balances: {'qzTeam': _qtc(teamHolds), 'qzMain': _qtc(mainHolds), 'qzSavings': oneToken, 'qzVault': oneToken},
    approval: approval,
    chain: chain,
  ),
  openExternalUrlProvider.overrideWithValue((url) async => _opened.add(url)),
  shareTextProvider.overrideWithValue((text, {origin}) async => _shared.add(text)),
];

/// Opens the wallet on the multisig and presses Propose in the toolbar.
Future<FakeSendChain> _openPropose(
  WidgetTester tester, {
  FakeSendChain? chain,
  FakeUserApproval? approval,
  num teamHolds = 4800,
  num mainHolds = 1250,
  Size? window,
}) async {
  _opened.clear();
  _shared.clear();
  chain ??= FakeSendChain();
  await pumpShell(
    tester,
    overrides: _overrides(
      multisig: _team,
      chain: chain,
      approval: approval,
      teamHolds: teamHolds,
      mainHolds: mainHolds,
    ),
  );
  if (window != null) {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
  }
  await tester.tap(_toolbarPropose());
  await tester.pumpAndSettle();
  return chain;
}

Future<void> _type(WidgetTester tester, Key field, String text) async {
  await tester.enterText(_editable(field), text);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String recipient = 'qzPayee', String amount = '250'}) async {
  await _type(tester, SendSheet.addressFieldKey, recipient);
  await _type(tester, SendSheet.amountFieldKey, amount);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _toReview(WidgetTester tester) async {
  await _fill(tester);
  await _tap(tester, SendSheet.reviewKey);
}

Future<void> _toReceipt(WidgetTester tester) async {
  await _toReview(tester);
  await _tap(tester, SendSheet.sendKey);
}

void main() {
  group('where Propose is offered', () {
    for (final (why, member) in [('signs on a hardware wallet', 'qzVault'), ('is not in this wallet', 'qzGone')]) {
      testOnMac('it is unavailable, in the toolbar and the menu, for a multisig whose member $why', (tester) async {
        final multisig = MultisigAccount(
          name: 'Team',
          accountId: 'qzTeam',
          signers: [member, 'qzOther'],
          threshold: 2,
          nonce: BigInt.zero,
          myMemberAccountId: member,
        );
        await pumpShell(tester, overrides: _overrides(multisig: multisig));

        expect(tester.widget<ToolbarAction>(_toolbarPropose()).onPressed, isNull);
        final menu = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
        final items = [
          for (final entry in menu.singleWhere((m) => m.label == 'Account').menus)
            if (entry is PlatformMenuItemGroup) ...entry.members else entry,
        ];
        expect(items.singleWhere((item) => item.label == 'Propose').onSelected, isNull);

        await tester.tap(_toolbarPropose(), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(ShellSheetView), findsNothing);
      });
    }
  });

  group('the form', () {
    testOnMac('opens titled Propose on the multisig, with what the multisig holds to give', (tester) async {
      await _openPropose(tester);

      expect(_inSheet(find.text('Propose')), findsOneWidget);
      expect(find.descendant(of: find.byType(ShellSheetHeader), matching: find.text('Team')), findsOneWidget);
      expect(_inSheet(find.text('Available')), findsOneWidget);
      expect(_inSheet(find.text('4,800 QTC')), findsOneWidget);
      expect(_inSheet(find.text('Propose the maximum amount')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('says what proposing costs and names the account that pays it, before anyone is named to pay', (
      tester,
    ) async {
      final chain = await _openPropose(tester);

      expect(_inSheet(find.text('Proposal cost')), findsOneWidget);
      expect(_inSheet(find.text('0.6012 QTC, paid by')), findsOneWidget);
      expect(_accountBeside(tester, 'Proposal cost', 'Main'), findsOneWidget);
      // Priced to the multisig itself until there is a recipient.
      expect(chain.proposalQuotes, ['qzTeam']);
    });

    testOnMac('prices the proposal to the recipient once there is one', (tester) async {
      final chain = await _openPropose(tester);

      await _fill(tester);

      expect(chain.proposalQuotes.last, 'qzPayee');
      expect(_inSheet(find.text('0.6012 QTC, paid by')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    testOnMac('a cost that cannot be had says so, with a way to ask again', (tester) async {
      final chain = FakeSendChain()..proposalCost = () async => throw StateError('offline');
      await _openPropose(tester, chain: chain);

      expect(_inSheet(find.text('Unable to estimate fee')), findsOneWidget);
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);

      chain.proposalCost = () async => FakeSendChain.usualProposalCost;
      await _tap(tester, SendSheet.retryFeeKey);

      expect(_inSheet(find.text('0.6012 QTC, paid by')), findsOneWidget);
    });

    testOnMac('when the member\'s account cannot pay the cost, it says so by name and Review is unavailable', (
      tester,
    ) async {
      await _openPropose(tester, mainHolds: 0.2);

      await _fill(tester);

      final problem = find.byKey(SendSheet.costProblemKey);
      expect(tester.widget<Text>(problem).data, 'Main does not hold enough to pay the proposal cost.');
      // Under the cost, and not the amount's to answer for.
      expect(
        tester.getRect(problem).top,
        greaterThanOrEqualTo(tester.getRect(_inSheet(find.text('Proposal cost'))).bottom),
      );
      expect(
        find.descendant(of: find.byKey(SendSheet.amountFieldKey), matching: find.textContaining('does not hold')),
        findsNothing,
      );
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('more than the multisig holds is said under the amount', (tester) async {
      await _openPropose(tester);

      await _fill(tester, amount: '5000');

      expect(_inSheet(find.textContaining('4,800 QTC')), findsNWidgets(2));
      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('the maximum is all the multisig holds, since its cost is paid elsewhere, and locks the amount', (
      tester,
    ) async {
      await _openPropose(tester);
      await _type(tester, SendSheet.addressFieldKey, 'qzPayee');

      await tester.tap(find.descendant(of: find.byKey(SendSheet.maxKey), matching: find.byType(Checkbox)));
      await tester.pumpAndSettle();

      expect(tester.widget<DesktopCheckbox>(find.byKey(SendSheet.maxKey)).value, isTrue);
      expect(_typed(tester, SendSheet.amountFieldKey), '4800');
      expect(tester.widget<EditableText>(_editable(SendSheet.amountFieldKey)).readOnly, isTrue);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    testOnMac('the multisig itself is refused as its own', (tester) async {
      await _openPropose(tester);

      await _fill(tester, recipient: 'qzTeam');

      expect(_canPress(tester, SendSheet.reviewKey), isFalse);
    });

    testOnMac('in the smallest window the form is whole, its buttons in reach', (tester) async {
      await _openPropose(tester, window: _smallestWindow);
      await _fill(tester);

      final sheet = tester.getRect(find.byType(ShellSheetView));
      expect(tester.takeException(), isNull);
      expect(sheet.bottom, lessThanOrEqualTo(_smallestWindow.height));
      expect(tester.getRect(find.byKey(SendSheet.reviewKey)).bottom, lessThan(sheet.bottom));
    });
  });

  group('the review', () {
    testOnMac('shows the way back, the amount and who is paid in full', (tester) async {
      await _openPropose(tester);

      await _toReview(tester);

      expect(find.descendant(of: find.byKey(ShellSheetHeader.backKey), matching: find.text('Propose')), findsOneWidget);
      expect(_inSheet(find.text('Review')), findsOneWidget);
      expect(_inSheet(find.text('PROPOSING')), findsOneWidget);
      expect(_inSheet(find.text('250')), findsOneWidget);
      final address = tester.getRect(_inSheet(find.text('qzPayee')));
      final phrase = tester.getRect(_inSheet(find.text('Phrase-qzPayee')));
      expect(phrase.top, greaterThanOrEqualTo(address.bottom));
      expect(phrase.left, address.left);
    });

    testOnMac('names the multisig the transfer leaves and the member who proposes, each by badge and name', (
      tester,
    ) async {
      await _openPropose(tester);

      await _toReview(tester);

      expect(_accountBeside(tester, 'From', 'Team'), findsOneWidget);
      expect(_accountBeside(tester, 'Proposed by', 'Main'), findsOneWidget);
    });

    testOnMac('draws the approvals needed as marks, none given yet, with how many of the signers', (tester) async {
      await _openPropose(tester);

      await _toReview(tester);

      expect(_inSheet(find.text('Approvals needed')), findsOneWidget);
      expect(_inSheet(find.text('2 of 3')), findsOneWidget);
      final marks = tester.widget<ApprovalMarks>(_inSheet(find.byType(ApprovalMarks)));
      expect((marks.approved, marks.needed), (0, 2));
    });

    testOnMac('says when the proposal expires, the block quieter after the date', (tester) async {
      await _openPropose(tester);

      await _toReview(tester);

      expect(_inSheet(find.text('Expires')), findsOneWidget);
      final date = _inSheet(find.text('~Nov 20, 2026 · 10:14 PM'));
      final block = _inSheet(find.text('Block 1284220'));
      expect(date, findsOneWidget);
      expect(block, findsOneWidget);
      expect(tester.getRect(block).left, greaterThan(tester.getRect(date).right));
      expect(tester.widget<Text>(block).style?.color, const AppColorsV3.dark().textMuted2);
    });

    testOnMac('lists what proposing costs, the deposit tagged as refundable, and what the member\'s account pays', (
      tester,
    ) async {
      await _openPropose(tester);

      await _toReview(tester);

      expect(_inSheet(find.text('Network fee')), findsOneWidget);
      expect(_inSheet(find.text('0.0012 QTC')), findsOneWidget);
      expect(_inSheet(find.text('Deposit')), findsOneWidget);
      expect(_inSheet(find.text('0.5 QTC')), findsOneWidget);
      final tag = _inSheet(find.byType(QuantusBadge));
      expect(tester.widget<QuantusBadge>(tag).label, 'refundable');
      expect(
        tester.getCenter(tag).dy,
        moreOrLessEquals(tester.getCenter(_inSheet(find.text('Deposit'))).dy, epsilon: 2),
      );
      expect(_inSheet(find.text('Proposal fee')), findsOneWidget);
      expect(_inSheet(find.text('0.1 QTC')), findsOneWidget);
      expect(_accountBeside(tester, 'pays', 'Main'), findsOneWidget);
      expect(_inSheet(find.text('0.6012 QTC')), findsOneWidget);
      // The phone's labels are not the desktop's.
      expect(_inSheet(find.text('You pay')), findsNothing);
      expect(_inSheet(find.text('THRESHOLD')), findsNothing);
    });

    testOnMac('Submit Proposal asks for approval, then submits what was reviewed, once', (tester) async {
      final approval = FakeUserApproval();
      final chain = await _openPropose(tester, approval: approval);
      await _toReview(tester);

      expect(_inSheet(find.text('Submit Proposal')), findsOneWidget);
      await _tap(tester, SendSheet.sendKey);

      expect(approval.reasons, ['Authenticate to propose transaction']);
      expect(chain.proposals, [
        (multisig: 'qzTeam', signer: 'qzMain', recipient: 'qzPayee', amount: _qtc(250), expiryBlock: 1284220),
      ]);
      expect(chain.transfers, isEmpty);
    });

    testOnMac('a declined approval submits nothing and says so beside the buttons', (tester) async {
      final chain = await _openPropose(
        tester,
        approval: FakeUserApproval()..answer = () async => ApprovalResult.declined,
      );
      await _toReview(tester);

      await _tap(tester, SendSheet.sendKey);

      expect(chain.proposals, isEmpty);
      expect(_inSheet(find.text('Authentication required')), findsOneWidget);
      expect(_inSheet(find.text('PROPOSING')), findsOneWidget);
    });

    testOnMac('a proposal the network refuses stays on the review, with why', (tester) async {
      final chain = FakeSendChain()..submit = () async => throw StateError('refused');
      await _openPropose(tester, chain: chain);
      await _toReview(tester);

      await _tap(tester, SendSheet.sendKey);

      expect(_inSheet(find.text('Failed to create proposal')), findsOneWidget);
      expect(_inSheet(find.text('PROPOSING')), findsOneWidget);
      expect(_canPress(tester, SendSheet.sendKey), isTrue);
    });

    testOnMac('in the smallest window the rows scroll and the buttons stay in reach', (tester) async {
      final chain = await _openPropose(tester, window: _smallestWindow);

      await _toReview(tester);

      final sheet = tester.getRect(find.byType(ShellSheetView));
      expect(tester.takeException(), isNull);
      expect(sheet.bottom, lessThanOrEqualTo(_smallestWindow.height));
      expect(tester.getRect(find.byKey(SendSheet.sendKey)).bottom, lessThan(sheet.bottom));

      // What the member pays stays in view over the buttons, whatever the
      // rows above it do.
      final submit = tester.getRect(find.byKey(SendSheet.sendKey));
      final scroll = tester.getRect(_inSheet(find.byType(SingleChildScrollView)));
      final total = tester.getRect(_inSheet(find.text('pays')));
      expect(total.top, greaterThanOrEqualTo(scroll.bottom));
      expect(total.bottom, lessThan(submit.top));

      // The last of the rows can be brought into view.
      await tester.ensureVisible(_inSheet(find.text('Proposal fee')));
      await tester.pumpAndSettle();
      expect(tester.getRect(_inSheet(find.text('Proposal fee'))).bottom, lessThanOrEqualTo(scroll.bottom));

      await _tap(tester, SendSheet.sendKey);
      expect(chain.proposals, hasLength(1));
    });
  });

  group('the receipt', () {
    testOnMac('says what was proposed and that the other signers must approve', (tester) async {
      await _openPropose(tester);

      await _toReceipt(tester);

      expect(_inSheet(find.text('SUBMITTED')), findsOneWidget);
      expect(_inSheet(find.text('250 QTC proposed')), findsOneWidget);
      expect(_inSheet(find.text('Co-signers must approve before the transfer can execute.')), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('Phrase-qzPayee')), findsOneWidget);
      expect(find.byKey(ShellSheetHeader.backKey), findsNothing);
    });

    testOnMac('shows the proposer\'s approval as the first of those needed, the expiry, and what was paid', (
      tester,
    ) async {
      await _openPropose(tester);

      await _toReceipt(tester);

      expect(_accountBeside(tester, 'From', 'Team'), findsOneWidget);
      expect(_inSheet(find.text('Approvals')), findsOneWidget);
      expect(_inSheet(find.text('1 of 2')), findsOneWidget);
      final marks = tester.widget<ApprovalMarks>(_inSheet(find.byType(ApprovalMarks)));
      expect((marks.approved, marks.needed), (1, 2));
      expect(_inSheet(find.text('~Nov 20, 2026 · 10:14 PM')), findsOneWidget);
      expect(_accountBeside(tester, 'paid', 'Main'), findsOneWidget);
      expect(_inSheet(find.text('0.6012 QTC')), findsOneWidget);
      // The total names who paid; its parts and the proposer are the review's.
      for (final label in ['Proposed by', 'Network fee', 'Deposit', 'Proposal fee', 'Approvals needed']) {
        expect(_inSheet(find.text(label)), findsNothing, reason: label);
      }
    });

    testOnMac('View in Explorer opens the proposal\'s transaction, and Share hands its link to the share picker', (
      tester,
    ) async {
      await _openPropose(tester);
      await _toReceipt(tester);
      final page = '${AppConstants.explorerEndpoint}/multisig-proposal-created/0xhash';

      await _tap(tester, SendSheet.explorerKey);
      await _tap(tester, SendSheet.shareKey);

      expect(_opened, [Uri.parse(page)]);
      expect(_shared, [page]);
      expect(
        tester.getRect(find.byKey(SendSheet.shareKey)).left,
        greaterThan(tester.getRect(find.byKey(SendSheet.explorerKey)).right),
      );
    });

    testOnWindowsAndLinux('there is no Share where the system has no share picker', (tester) async {
      await _openPropose(tester);

      await _toReceipt(tester);

      expect(find.byKey(SendSheet.explorerKey), findsOneWidget);
      expect(find.byKey(SendSheet.shareKey), findsNothing);
    });

    testOnMac('in the smallest window nothing overflows and Done stays in the sheet', (tester) async {
      await _openPropose(tester, window: _smallestWindow);

      await _toReceipt(tester);

      final sheet = tester.getRect(find.byType(ShellSheetView));
      expect(tester.takeException(), isNull);
      expect(sheet.bottom, lessThanOrEqualTo(_smallestWindow.height));
      expect(tester.getRect(find.byKey(SendSheet.doneKey)).bottom, lessThan(sheet.bottom));
    });

    testOnMac('Done closes the sheet, and Propose opens empty again', (tester) async {
      await _openPropose(tester);
      await _toReceipt(tester);

      await _tap(tester, SendSheet.doneKey);
      expect(find.byType(ShellSheetView), findsNothing);

      await tester.tap(_toolbarPropose());
      await tester.pumpAndSettle();

      expect(_typed(tester, SendSheet.addressFieldKey), isEmpty);
      expect(_typed(tester, SendSheet.amountFieldKey), isEmpty);
      expect(_inSheet(find.byType(SendSummary)), findsNothing);
    });
  });

  group('the shortcut', () {
    testOnMac('Propose is ⌘P in the Account menu', (tester) async {
      await pumpShell(tester, overrides: _overrides(multisig: _team));

      final menu = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
      final propose = [
        for (final entry in menu.singleWhere((m) => m.label == 'Account').menus)
          if (entry is PlatformMenuItemGroup) ...entry.members else entry,
      ].singleWhere((item) => item.label == 'Propose');
      final shortcut = propose.shortcut! as SingleActivator;
      expect(
        (shortcut.trigger, shortcut.meta, shortcut.control, shortcut.alt, shortcut.shift),
        (LogicalKeyboardKey.keyP, true, false, false, false),
      );
    });

    testOnWindowsAndLinux('Ctrl+P opens Propose on a multisig', (tester) async {
      await pumpShell(tester, overrides: _overrides(multisig: _team));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('Propose')), findsOneWidget);
      expect(find.byKey(SendSheet.addressFieldKey), findsOneWidget);
    });

    testOnWindowsAndLinux('Ctrl+P pressed while the switch to the multisig is still being saved opens Propose on it', (
      tester,
    ) async {
      final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount), multisigs: [_team]);
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount, savingsAccount],
          settings: settings,
          balances: {'qzTeam': _qtc(4800), 'qzMain': _qtc(1250), 'qzSavings': oneToken},
        ),
      );

      await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Team')));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settings.finishWrites(tester);

      expect(_inSheet(find.text('Propose')), findsOneWidget);
      expect(find.descendant(of: find.byType(ShellSheetHeader), matching: find.text('Team')), findsOneWidget);
      expect(_inSheet(find.text('4,800 QTC')), findsOneWidget);
    });

    testOnWindowsAndLinux('Ctrl+P does nothing on an account that does not propose', (tester) async {
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount],
          settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
          balances: oneTokenEach,
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });
  });
}
