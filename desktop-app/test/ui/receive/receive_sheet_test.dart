import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/receive/receive_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder _action(Key key) => find.byKey(key);

/// What was shared, and from where.
final _shared = <(String, Rect?)>[];

/// Opens Receive for [active]. The encrypted account's next deposit address
/// comes from [depositAddress].
Future<void> _openReceive(
  WidgetTester tester,
  DisplayAccount active, {
  Future<String> Function()? depositAddress,
  bool settle = true,
}) async {
  _shared.clear();
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, encryptedAccount],
        settings: FakeSettingsService(activeAccount: active),
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
        depositAddress: (walletIndex) {
          expect(walletIndex, 0);
          return (depositAddress ?? () async => fail('no deposit address expected'))();
        },
      ),
      shareTextProvider.overrideWithValue((text, {origin}) async => _shared.add((text, origin))),
    ],
  );
  await tester.tap(
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Receive')),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

/// What the app put on the clipboard last.
String? _clipboard;

void _recordClipboard(WidgetTester tester) {
  _clipboard = null;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') _clipboard = (call.arguments as Map)['text'] as String?;
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

String _label(WidgetTester tester, Key key) => tester.widget<ToolbarAction>(_action(key)).label;

void main() {
  testOnMac('shows the account, its QR code, the address unbroken, the checkphrase and the footnote', (tester) async {
    await _openReceive(tester, const RegularAccount(mainAccount));

    expect(_inSheet(find.text('Receive')), findsOneWidget);
    expect(_inSheet(find.text('Main')), findsOneWidget);
    expect(_inSheet(find.byType(AccountBadge)), findsOneWidget);
    expect(tester.widget<QuantusQr>(_inSheet(find.byType(QuantusQr))).accountId, 'qzMain');
    expect(_inSheet(find.text('YOUR ADDRESS')), findsOneWidget);
    expect(_inSheet(find.text('qzMain')), findsOneWidget);
    expect(_inSheet(find.text('CHECKPHRASE')), findsOneWidget);
    expect(_inSheet(find.text('Phrase-qzMain')), findsOneWidget);
    expect(_inSheet(find.text('Ask the sender to confirm this phrase matches your address.')), findsOneWidget);
    expect(find.byKey(ReceiveSheet.encryptedNoticeKey), findsNothing);
  });

  testOnMac('Copy beside the address copies it, and says Copied for two seconds', (tester) async {
    _recordClipboard(tester);
    await _openReceive(tester, const RegularAccount(mainAccount));

    await tester.tap(_action(ReceiveSheet.copyAddressKey));
    await tester.pump();

    expect(_clipboard, 'qzMain');
    expect(_label(tester, ReceiveSheet.copyAddressKey), 'Copied');

    await tester.pump(const Duration(seconds: 2));

    expect(_label(tester, ReceiveSheet.copyAddressKey), 'Copy');
  });

  testOnMac('Copy beside the checkphrase copies the checkphrase', (tester) async {
    _recordClipboard(tester);
    await _openReceive(tester, const RegularAccount(mainAccount));

    await tester.tap(_action(ReceiveSheet.copyCheckphraseKey));
    await tester.pump();

    expect(_clipboard, 'Phrase-qzMain');
    expect(_label(tester, ReceiveSheet.copyCheckphraseKey), 'Copied');
    await tester.pump(const Duration(seconds: 2));
  });

  testOnMac('the encrypted account is paid at its next deposit address, and says why it changes', (tester) async {
    _recordClipboard(tester);
    await _openReceive(tester, const RegularAccount(encryptedAccount), depositAddress: () async => 'qzDeposit7');

    expect(_inSheet(find.byType(EncryptedLockBadge)), findsOneWidget);
    expect(_inSheet(find.text('Encrypted Account')), findsOneWidget);
    expect(_inSheet(find.text('DEPOSIT ADDRESS')), findsOneWidget);
    expect(_inSheet(find.text('qzDeposit7')), findsOneWidget);
    expect(tester.widget<QuantusQr>(_inSheet(find.byType(QuantusQr))).accountId, 'qzDeposit7');
    expect(_inSheet(find.text('Phrase-qzDeposit7')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ReceiveSheet.encryptedNoticeKey),
        matching: find.text(
          'A new address once this one has been paid, so your deposits can’t be linked to each other.',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(_action(ReceiveSheet.copyAddressKey));
    await tester.pump();

    expect(_clipboard, 'qzDeposit7');
    await tester.pump(const Duration(seconds: 2));
  });

  testOnMac('a spinner holds the place of the deposit address while it is worked out', (tester) async {
    final derived = Completer<String>();
    await _openReceive(
      tester,
      const RegularAccount(encryptedAccount),
      depositAddress: () => derived.future,
      settle: false,
    );

    expect(_inSheet(find.byType(Loader)), findsOneWidget);
    expect(_inSheet(find.byType(QuantusQr)), findsNothing);

    derived.complete('qzDeposit7');
    await tester.pumpAndSettle();

    expect(_inSheet(find.byType(Loader)), findsNothing);
    expect(_inSheet(find.text('qzDeposit7')), findsOneWidget);
  });

  testOnMac('a deposit address that cannot be worked out is reported in the sheet', (tester) async {
    await _openReceive(
      tester,
      const RegularAccount(encryptedAccount),
      depositAddress: () async => throw StateError('keychain is locked'),
    );

    expect(_inSheet(find.text('Error loading account data: Bad state: keychain is locked')), findsOneWidget);
    expect(_inSheet(find.byType(QuantusQr)), findsNothing);
    expect(find.byKey(ReceiveSheet.copyAddressKey), findsNothing);
  });

  testOnMac('Share hands the address to the system share picker, from the Share button', (tester) async {
    await _openReceive(tester, const RegularAccount(mainAccount));

    await tester.tap(_action(ReceiveSheet.shareKey));
    await tester.pump();

    expect(_shared.map((share) => share.$1), ['qzMain']);
    expect(_shared.single.$2, tester.getRect(_action(ReceiveSheet.shareKey)));
  });

  testOnWindowsAndLinux('there is no Share where the system has no share picker', (tester) async {
    await _openReceive(tester, const RegularAccount(mainAccount));

    expect(find.byKey(ReceiveSheet.shareKey), findsNothing);
    expect(find.byKey(ReceiveSheet.copyAddressKey), findsOneWidget);
  });

  testOnMac('a screen reader can press Copy and Share', (tester) async {
    final semantics = tester.ensureSemantics();
    _recordClipboard(tester);
    await _openReceive(tester, const RegularAccount(mainAccount));
    void press(Key key) => tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: tester.getSemantics(_action(key)).id,
      ),
    );

    press(ReceiveSheet.copyAddressKey);
    press(ReceiveSheet.shareKey);
    await tester.pump();

    expect(_clipboard, 'qzMain');
    expect(_shared.map((share) => share.$1), ['qzMain']);
    await tester.pump(const Duration(seconds: 2));
    semantics.dispose();
  });
}
