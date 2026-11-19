import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget badge) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Scaffold(body: Center(child: badge)),
        ),
      ),
    );
    await tester.pump();
  }

  double lockSize(WidgetTester tester) => tester.widget<QuantusIcon>(find.byType(QuantusIcon)).size;

  testWidgets('the lock is 40% of the badge unless told otherwise', (tester) async {
    await pump(tester, const EncryptedLockBadge());
    expect(lockSize(tester), 16);

    await pump(tester, const EncryptedLockBadge(size: 96));
    expect(lockSize(tester), moreOrLessEquals(38.4));
  });

  testWidgets('the lock is drawn at the size it is given', (tester) async {
    await pump(tester, const EncryptedLockBadge(size: 24, iconSize: 12));

    expect(tester.getSize(find.byType(EncryptedLockBadge)), const Size.square(24));
    expect(lockSize(tester), 12);
  });
}
