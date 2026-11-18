import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

const _address = 'qzpK3wXs9DfL2mVb7NcQ8rTy4HgJ6aZe1UoBi5WnRk7tYe';
const _colors = AppColorsV3.dark();

Future<void> _pump(WidgetTester tester) async {
  useFakeCheckphrases((address) async => 'Phrase-of-$address');
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: const Scaffold(
          body: Center(child: DesktopAddressCheckphrase(address: _address)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws the whole address, with nothing shortened, and its checkphrase', (tester) async {
    await _pump(tester);

    expect(find.text(_address), findsOneWidget);
    expect(find.text('Phrase-of-$_address'), findsOneWidget);
  });

  testWidgets('the address is on top and its checkphrase under it, from the same left edge', (tester) async {
    await _pump(tester);

    final address = tester.getRect(find.text(_address));
    final phrase = tester.getRect(find.text('Phrase-of-$_address'));
    expect(phrase.top, greaterThanOrEqualTo(address.bottom));
    expect(phrase.left, address.left);
  });

  testWidgets('both are in the monospaced face, the address white and the checkphrase lilac', (tester) async {
    await _pump(tester);

    final address = tester.widget<Text>(find.text(_address)).style!;
    final phrase = tester.widget<Text>(find.text('Phrase-of-$_address')).style!;
    expect(address.color, _colors.textWhite);
    expect(phrase.color, _colors.semanticLilac);
    expect(address.fontFamily, const AppTextThemeV3.desktop().dataAddressLarge.fontFamily);
    expect(phrase.fontFamily, address.fontFamily);
    expect(phrase.fontSize, address.fontSize);
  });
}
