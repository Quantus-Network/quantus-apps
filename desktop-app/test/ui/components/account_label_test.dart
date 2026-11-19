import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
}
