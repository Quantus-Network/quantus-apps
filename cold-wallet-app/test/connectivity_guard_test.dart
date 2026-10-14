import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/connectivity_guard.dart';
import 'package:quantus_cold_wallet/components/radio_status_panel.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StatusController extends WalletController {
  final WalletStatus status;

  _StatusController(this.status);

  @override
  WalletState build() => WalletState(status: status);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const dialogBody =
      "A signer is only safe while it's fully offline. Anything you approve from here could be exposed. "
      'For testing only, never with a key that holds real funds.';

  late StreamController<NetworkStatus> network;

  Future<void> pumpGuard(
    WidgetTester tester, {
    WalletStatus status = WalletStatus.locked,
    NetworkStatus network0 = NetworkStatus.online,
    List<ConnectivityResult> results = const [ConnectivityResult.wifi],
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    network = StreamController<NetworkStatus>()..add(network0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletControllerProvider.overrideWith(() => _StatusController(status)),
          networkStatusProvider.overrideWith((ref) => network.stream),
          connectivityResultsProvider.overrideWith((ref) => Stream.value(results)),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: const Scaffold(body: Text('route')),
            builder: (context, child) => Stack(children: [?child, const ConnectivityGuard()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ConnectivityGuard)));

  testWidgets('blocks with the onboarding copy before a key exists', (tester) async {
    await pumpGuard(tester, status: WalletStatus.needsSetup);

    expect(find.text('Network Detected'), findsOneWidget);
    expect(find.text('Go offline to continue'), findsOneWidget);
    expect(find.text('No key is created while this phone is connected.'), findsOneWidget);
    expect(find.text('Waiting for you to go offline'), findsNothing);
    expect(find.text("This clears itself the moment you're fully offline."), findsOneWidget);
    expect(find.text('Override for Testing'), findsOneWidget);
    expect(find.byType(AppBackButton), findsNothing);
  });

  testWidgets('blocks with the in-app copy once a key exists', (tester) async {
    await pumpGuard(tester, status: WalletStatus.locked);

    expect(find.text('Waiting for you to go offline'), findsOneWidget);
    expect(find.text("A signer can't unlock while it's connected."), findsOneWidget);
    expect(find.text('Go offline to continue'), findsNothing);
  });

  testWidgets('passes the reported radios to the status panel', (tester) async {
    await pumpGuard(tester, results: const [ConnectivityResult.wifi, ConnectivityResult.bluetooth]);

    final panel = tester.widget<RadioStatusPanel>(find.byType(RadioStatusPanel));
    expect(panel.results, const [ConnectivityResult.wifi, ConnectivityResult.bluetooth]);
  });

  testWidgets('renders nothing while offline', (tester) async {
    await pumpGuard(tester, network0: NetworkStatus.offline);

    expect(find.text('Network Detected'), findsNothing);
    expect(find.text('route'), findsOneWidget);
  });

  testWidgets('override confirms inline over a scrim and cancel steps back', (tester) async {
    await pumpGuard(tester);

    await tester.tap(find.text('Override for Testing'));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Sign while online?'));
    expect(title.style?.color, colors.semanticEmber);
    expect(find.text(dialogBody), findsOneWidget);
    expect(find.text('Override, I accept the risk'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Network Detected'), findsOneWidget);
    final scrim = tester.widget<ColoredBox>(
      find.ancestor(of: find.byType(QuantusDialog), matching: find.byType(ColoredBox)).first,
    );
    expect(scrim.color, colors.bgVoid.useOpacity(0.8));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign while online?'), findsNothing);
    expect(find.text('Network Detected'), findsOneWidget);
    expect(container(tester).read(coldSettingsProvider).wifiOverrideEnabled, isFalse);
  });

  testWidgets('confirming the override enables the setting and clears the gate', (tester) async {
    await pumpGuard(tester);

    await tester.tap(find.text('Override for Testing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Override, I accept the risk'));
    await tester.pumpAndSettle();

    expect(container(tester).read(coldSettingsProvider).wifiOverrideEnabled, isTrue);
    expect(find.text('Network Detected'), findsNothing);
    expect(find.text('Sign while online?'), findsNothing);
  });

  testWidgets('going offline clears the gate and drops a pending confirmation', (tester) async {
    await pumpGuard(tester);
    await tester.tap(find.text('Override for Testing'));
    await tester.pumpAndSettle();
    expect(find.text('Sign while online?'), findsOneWidget);

    network.add(NetworkStatus.offline);
    await tester.pumpAndSettle();
    expect(find.text('Network Detected'), findsNothing);
    expect(find.text('Sign while online?'), findsNothing);

    network.add(NetworkStatus.online);
    await tester.pumpAndSettle();
    expect(find.text('Network Detected'), findsOneWidget);
    expect(find.text('Sign while online?'), findsNothing);
  });
}
