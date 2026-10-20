import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_header_card.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';
import 'package:quantus_sdk/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pump_app.dart';

class _FakeSubstrateService implements SubstrateService {
  @override
  Future<BigInt> queryBalance(String address) async => BigInt.from(1234) * BigInt.from(10).pow(AppConstants.decimals);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  testWidgets('sidebar lists the tabs and the current account', (tester) async {
    final account = makeAccount(1, accountType: AccountType.keystone);
    var selected = -1;
    await tester.pumpApp(
      Sidebar(currentIndex: 0, onSelect: (i) => selected = i),
      overrides: [
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: [account])),
      ],
    );
    await tester.pump();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text(account.name), findsOneWidget);
    await tester.tap(find.text('Settings'));
    expect(selected, 5);
  });

  testWidgets('balance header shows the balance once it loads', (tester) async {
    final account = makeAccount(1, accountType: AccountType.keystone);
    await tester.pumpApp(
      const BalanceHeaderCard(label: 'TOTAL BALANCE'),
      overrides: [
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: [account])),
        substrateServiceProvider.overrideWithValue(_FakeSubstrateService()),
        exchangeRatesProvider.overrideWith((ref) async => ExchangeRateService.fallbackRates),
        tokenUsdPriceProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('1,234'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
  });
}
