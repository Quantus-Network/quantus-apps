import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/activity/transaction_detail_sheet.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  final me = makeAccount(1);
  final other = makeAccount(2);

  TransferEvent transfer({required String from, required String to}) => TransferEvent(
    id: 'tx-1',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: DateTime(2026, 9, 6),
    fee: BigInt.one,
    extrinsicHash: '0x9cbe',
    blockNumber: 1,
    blockHash: '0xblock',
  );

  Future<bool?> openSheet(WidgetTester tester, TransferEvent tx) async {
    bool? capturedIsSend;
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showTransactionDetailSheet(context, tx, me.accountId),
          child: const Text('open'),
        ),
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
          capturedIsSend = isSend;
          return CurrencyDisplayState(
            primaryAmount: '${isSend ? '-' : '+'}$amount',
            secondaryAmount: '',
            selectedFiat: FiatCurrency.usd,
          );
        }),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return capturedIsSend;
  }

  testWidgets('a received transfer is formatted as an inflow', (tester) async {
    final isSend = await openSheet(tester, transfer(from: other.accountId, to: me.accountId));

    expect(isSend, isFalse);
    expect(find.textContaining('+300'), findsOneWidget);
  });

  testWidgets('a private send without an attributable recipient names the aggregated batch', (tester) async {
    await openSheet(
      tester,
      WormholeTransferEvent(
        id: '0xbundle',
        from: me.accountId,
        to: '',
        amount: BigInt.from(300),
        timestamp: DateTime(2026, 9, 6),
        fee: BigInt.zero,
        extrinsicHash: '0xbundle',
        blockNumber: 1,
      ),
    );

    expect(find.text('Aggregated batch, recipient not recorded'), findsOneWidget);
  });

  testWidgets('a sent transfer is formatted as an outflow', (tester) async {
    final isSend = await openSheet(tester, transfer(from: me.accountId, to: other.accountId));

    expect(isSend, isTrue);
    expect(find.textContaining('-300'), findsOneWidget);
  });

  testWidgets('the share button hands the explorer link to the system share sheet', (tester) async {
    Map? shared;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        shared = call.arguments as Map;
        return '';
      },
    );
    await openSheet(tester, transfer(from: me.accountId, to: other.accountId));

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();

    final button = tester.getRect(find.byType(IconButton));
    expect(shared?['text'], '${AppConstants.explorerEndpoint}/immediate-transactions/0x9cbe');
    expect(shared?['originX'], button.left);
    expect(shared?['originY'], button.top);
    expect(shared?['originWidth'], button.width);
    expect(shared?['originHeight'], button.height);
  });
}
