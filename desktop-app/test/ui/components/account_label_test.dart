import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/hover_popover.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

Future<void> _pump(WidgetTester tester, Widget label, {double width = 400}) async {
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: Row(children: [Flexible(child: label)]),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _l10n = lookupAppLocalizations(const Locale('en'));

/// [label] in the app's scope, the pointer resting on it long enough for its
/// popover to open, if it has one.
Future<void> _hover(WidgetTester tester, AccountLabel label) async {
  useFakeCheckphrases(fakeCheckphrase);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsServiceProvider.overrideWithValue(FakeSettingsService())],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
          home: Scaffold(body: Center(child: label)),
        ),
      ),
    ),
  );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(find.byType(DesktopAccountBadge)));
  await tester.pump(HoverPopover.openAfter);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names an account by its badge, then its name on the same line', (tester) async {
    await _pump(tester, const AccountLabel(account: mainAccount));

    final badge = tester.getRect(find.byType(AccountBadge));
    final name = tester.getRect(find.text('Main'));
    expect(badge.size, const Size.square(24));
    expect(name.left, badge.right + AccountLabel.gap);
    expect(name.center.dy, moreOrLessEquals(badge.center.dy, epsilon: 1));
  });

  testWidgets('the Encrypted account has its lock, never initials', (tester) async {
    await _pump(tester, const AccountLabel(account: encryptedAccount));

    expect(find.byType(EncryptedLockBadge), findsOneWidget);
    expect(find.byType(AccountBadge), findsNothing);
    expect(find.text('Encrypted Account'), findsOneWidget);
  });

  testWidgets('a multisig is named the same way', (tester) async {
    await _pump(tester, AccountLabel(account: teamMultisig));

    expect(find.byType(AccountBadge), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
  });

  testWidgets('the badge can be drawn at another size, and the name in another style', (tester) async {
    await _pump(
      tester,
      const AccountLabel(
        account: mainAccount,
        size: 22,
        style: TextStyle(fontSize: 13, color: Color(0xFF112233)),
      ),
    );

    expect(tester.getSize(find.byType(DesktopAccountBadge)), const Size.square(22));
    expect(tester.widget<Text>(find.text('Main')).style?.color, const Color(0xFF112233));
  });

  testWidgets('a name too long for the room is cut short, and the badge stays whole', (tester) async {
    const long = Account(
      walletIndex: 0,
      index: 0,
      name: 'An account with a very long name indeed',
      accountId: 'qzLong',
    );

    await _pump(tester, const AccountLabel(account: long), width: 120);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AccountBadge)), const Size.square(AccountLabel.badgeSize));
    expect(tester.getSize(find.byType(AccountLabel)).width, lessThanOrEqualTo(120));
  });

  group('as a sender or receiver (revealsAddress)', () {
    testWidgets('hovering it shows its whole address over its checkphrase, and Copy copies the address', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });

      await _hover(tester, const AccountLabel(account: mainAccount, revealsAddress: true));

      final popover = find.byKey(HoverPopover.boxKey);
      expect(find.descendant(of: popover, matching: find.text(_l10n.desktopMarksAddress.toUpperCase())), findsOne);
      final address = tester.getRect(find.descendant(of: popover, matching: find.text('qzMain')));
      final phrase = tester.getRect(find.descendant(of: popover, matching: find.text('Phrase-qzMain')));
      expect(phrase.top, greaterThan(address.top));

      await tester.tap(find.descendant(of: popover, matching: find.text(_l10n.receiveCopy)));
      await tester.pump();
      expect(copied, ['qzMain']);
      expect(find.descendant(of: popover, matching: find.text(_l10n.desktopCopied)), findsOne);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a screen reader hears its name and its address', (tester) async {
      final semantics = tester.ensureSemantics();
      await _hover(tester, const AccountLabel(account: mainAccount, revealsAddress: true));

      expect(tester.getSemantics(find.byType(AccountLabel)), isSemantics(label: 'Main, qzMain'));
      semantics.dispose();
    });

    testWidgets('the Encrypted account has no single address, so hovering it shows nothing', (tester) async {
      await _hover(tester, const AccountLabel(account: encryptedAccount, revealsAddress: true));

      expect(find.byKey(HoverPopover.boxKey), findsNothing);
    });
  });

  testWidgets('naming the open account (a sheet\'s header, the top bar), hovering it shows nothing', (tester) async {
    await _hover(tester, const AccountLabel(account: mainAccount));

    expect(find.byKey(HoverPopover.boxKey), findsNothing);
  });
}
