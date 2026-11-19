import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

Future<void> _pump(WidgetTester tester, Widget badge) async {
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(body: Center(child: badge)),
      ),
    ),
  );
  await tester.pump();
}

double _initialsSize(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byType(AccountBadge), matching: find.byType(Text))).style!.fontSize!;

double _lockSize(WidgetTester tester) => tester.widget<QuantusIcon>(find.byType(QuantusIcon)).size;

void main() {
  testWidgets('initials are 10pt in a badge beside text and 12pt in the sidebar\'s', (tester) async {
    await _pump(tester, const DesktopAccountBadge(account: mainAccount, size: 24));
    expect(_initialsSize(tester), 10);

    await _pump(tester, const DesktopAccountBadge(account: mainAccount, size: 32));
    expect(_initialsSize(tester), 12);
  });

  testWidgets('the lock is half its badge', (tester) async {
    await _pump(tester, const DesktopAccountBadge(account: encryptedAccount, size: 24));
    expect(_lockSize(tester), 12);

    await _pump(tester, const DesktopAccountBadge(account: encryptedAccount, size: 32));
    expect(_lockSize(tester), 16);
  });
}
