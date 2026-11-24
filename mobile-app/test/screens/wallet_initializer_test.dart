import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';
import 'package:resonance_network_wallet/wallet_initializer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/combined_transactions_list.dart';
import 'package:wallet_core/models/fiat_currency.dart';
import 'package:wallet_core/providers/active_account_transactions_provider.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/exchange_rate_service.dart';
import 'package:wallet_core/services/logout_service.dart';

import '../extensions.dart';
import '../fakes.dart';

/// A logout that only counts.
class _CountingLogout extends Fake implements LogoutService {
  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;
}

/// What the app does at start when the first wallet's recovery phrase cannot
/// be read: it is wiped only when the person asks, and confirms.
void main() {
  const root = Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'qzRoot');
  const notice = 'Unable to read your recovery phrase from this device.';
  const confirmTitle = 'Remove all wallets from this device?';

  late _CountingLogout logout;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final settings = SettingsService();
    await settings.initialize();
    await settings.saveAccounts([root]);
    await settings.setActiveAccount(const RegularAccount(root));
    await settings.setMainnetMigrationDone();
    logout = _CountingLogout();
    recordTelemetry();
  });

  Finder button(String label) => find.widgetWithText(QuantusButton, label);

  // Behind the sheet a spinner turns, which never settles.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpStart(WidgetTester tester) async {
    await tester.pumpApp(
      const WalletInitializer(),
      overrides: [
        logoutServiceProvider.overrideWithValue(logout),
        // What Home needs once the phrase is found.
        localAuthProvider.overrideWith((ref) => TestLocalAuthController(authenticated: true)),
        isOnlineProvider.overrideWith((ref) => true),
        activeAccountTransactionsProvider.overrideWith(
          (ref, filter) => AsyncValue.data(CombinedTransactionsList.empty),
        ),
        balanceProvider.overrideWithValue(AsyncValue.data(BigInt.from(10).pow(15))),
        balanceProviderFamily.overrideWith((ref, accountId) async => BigInt.from(10).pow(15)),
        balanceDisplayProvider.overrideWithValue(
          const AsyncValue.data(
            CurrencyDisplayState(primaryAmount: '10', secondaryAmount: '10', selectedFiat: FiatCurrency.usd),
          ),
        ),
        backupReminderWalletIndexProvider.overrideWithValue(null),
        exchangeRateServiceProvider.overrideWithValue(ExchangeRateService(rates: {})),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
        substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
        remoteConfigProvider.overrideWith((ref) {
          final config = RemoteConfigModel.fromJson({});
          return RemoteConfigNotifier(FakeRemoteConfigService(config, remote: config));
        }),
      ],
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  testWidgets('the sheet offers Try Again and Remove Wallet, comes back when dismissed, and wipes nothing', (
    tester,
  ) async {
    await pumpStart(tester);

    expect(find.text('Wallet Error'), findsOneWidget);
    expect(find.text(notice), findsOneWidget);
    expect(button('Try Again'), findsOneWidget);
    expect(button('Remove Wallet'), findsOneWidget);
    expect(button('OK'), findsNothing);

    // A tap above the sheet dismisses it; it is asked again.
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);

    expect(find.text(notice), findsOneWidget);
    expect(logout.logouts, 0);
  });

  testWidgets('Try Again with the phrase readable again opens Home and wipes nothing', (tester) async {
    await pumpStart(tester);
    await SettingsService().setMnemonic('a stored recovery phrase', 0);

    await tap(tester, button('Try Again'));

    expect(find.text(notice), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(logout.logouts, 0);
  });

  testWidgets('Remove Wallet, once confirmed, wipes and shows Welcome', (tester) async {
    await pumpStart(tester);

    await tap(tester, button('Remove Wallet'));
    expect(find.text(confirmTitle), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    await tap(tester, button('Remove'));

    expect(logout.logouts, 1);
    expect(find.byType(WelcomeScreenV2), findsOneWidget);
  });

  testWidgets('cancelling the confirmation wipes nothing and asks again', (tester) async {
    await pumpStart(tester);

    await tap(tester, button('Remove Wallet'));
    await tap(tester, button('Cancel'));

    expect(find.text(confirmTitle), findsNothing);
    expect(find.text(notice), findsOneWidget);
    expect(logout.logouts, 0);
  });
}
