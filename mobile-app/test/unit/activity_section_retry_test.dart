import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/skeleton.dart';
import 'package:resonance_network_wallet/v2/screens/home/activity_section.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  final me = makeAccount(1);

  testWidgets('Retry shows the loading skeleton until the reload settles', (tester) async {
    final reload = Completer<void>();
    await tester.pumpApp(
      ActivitySection(
        txAsync: AsyncValue.error(StateError('indexer down'), StackTrace.empty),
        activeAccount: me,
        onRetry: () => reload.future,
      ),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(me))),
        txAmountDisplayProvider.overrideWithValue((
          BigInt amount, {
          required bool isSend,
          int tokenDecimals = 12,
          bool withTokenSymbol = true,
          bool withSignPrefix = true,
        }) {
          return CurrencyDisplayState(primaryAmount: '$amount', secondaryAmount: '', selectedFiat: FiatCurrency.usd);
        }),
      ],
    );
    expect(find.byType(TxItemSkeleton), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byType(TxItemSkeleton), findsWidgets);
    expect(find.text('Retry'), findsNothing);

    reload.complete();
    await tester.pump();

    expect(find.byType(TxItemSkeleton), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}
