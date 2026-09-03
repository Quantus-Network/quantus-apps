import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

/// The send amount screen has to survive a keyboard eating most of the
/// viewport: the fiat conversion line stays reachable on a normal phone, and a
/// short phone scrolls rather than overflowing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  Future<void> pumpAmountScreen(
    WidgetTester tester, {
    required Size size,
    required double keyboardInset,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final recipient = makeAccount(2);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(makeAccount(1)))),
          humanReadableChecksumServiceProvider.overrideWithValue(FakeHumanReadableChecksumService()),
          effectiveMaxBalanceProviderFamily.overrideWith(
            (ref, accountId) => AsyncValue.data(BigInt.from(5000000000000)),
          ),
          regularSendFeeProvider.overrideWith(
            (ref, key) => AsyncValue.data(RegularFee(networkFee: BigInt.from(12964885))),
          ),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: textScaler,
                viewInsets: EdgeInsets.only(bottom: keyboardInset),
              ),
              child: InputAmountScreen(
                strategy: RegularSendStrategy(account: makeAccount(1)),
                recipientAddress: recipient.accountId,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a short phone with the keyboard up scrolls instead of overflowing', (tester) async {
    await pumpAmountScreen(tester, size: const Size(360, 640), keyboardInset: 260);

    expect(tester.takeException(), isNull);

    final scroller = find.descendant(of: find.byType(InputAmountScreen), matching: find.byType(SingleChildScrollView));
    expect(scroller, findsOneWidget);
    final position = tester
        .state<ScrollableState>(find.descendant(of: scroller, matching: find.byType(Scrollable)).first)
        .position;
    expect(position.maxScrollExtent, greaterThan(0), reason: 'the squeezed layout must scroll, not overflow');
  });

  testWidgets('the largest accessibility text scrolls instead of overflowing', (tester) async {
    await pumpAmountScreen(
      tester,
      size: const Size(430, 932),
      keyboardInset: 0,
      textScaler: const TextScaler.linear(3),
    );

    expect(tester.takeException(), isNull);

    final scroller = find.descendant(of: find.byType(InputAmountScreen), matching: find.byType(SingleChildScrollView));
    final position = tester
        .state<ScrollableState>(find.descendant(of: scroller, matching: find.byType(Scrollable)).first)
        .position;
    expect(position.maxScrollExtent, greaterThan(0), reason: 'the tall layout must scroll, not overflow');
  });

  testWidgets('the fiat conversion line stays on screen with the keyboard up', (tester) async {
    await pumpAmountScreen(tester, size: const Size(390, 844), keyboardInset: 336);
    expect(tester.takeException(), isNull);

    final fiat = find.textContaining('≈');
    expect(fiat, findsOneWidget);

    // Visible means inside the viewport, not merely present in the tree.
    final fiatRect = tester.getRect(fiat);
    final divider = tester.getRect(find.byType(ScaffoldBaseBottomContent));
    expect(
      fiatRect.bottom,
      lessThanOrEqualTo(divider.top),
      reason: 'fiat line at $fiatRect is hidden behind the bottom panel at $divider',
    );
  });
}
