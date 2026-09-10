import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/mainnet_migration_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mainnet_migration_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/settings/reset_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/mainnet_migration_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

class _Settings extends FakeSettingsService {
  bool migrationDone = false;
  bool failWrite = false;

  @override
  bool isMainnetMigrationDone() => migrationDone;

  @override
  Future<void> setMainnetMigrationDone() async {
    if (failWrite) throw Exception('disk full');
    migrationDone = true;
  }
}

final _miner = TestnetStatus(blocksMined: 1234, balance: BigInt.zero);
final _holder = TestnetStatus(blocksMined: 0, balance: BigInt.from(7));
final _newcomer = TestnetStatus(blocksMined: 0, balance: BigInt.zero);

void main() {
  final finish = find.byKey(const Key(E2EKeys.mainnetMigrationFinishButton));
  final createWallet = find.byKey(const Key(E2EKeys.mainnetMigrationCreateWalletButton));

  /// Pumps the flow, taps Next and lets the page animation finish.
  Future<({_Settings settings, List<bool> finished})> pumpSecondPage(
    WidgetTester tester,
    Future<TestnetStatus> Function() status, {
    bool failWrite = false,
  }) async {
    final settings = _Settings()..failWrite = failWrite;
    final finished = <bool>[];
    await tester.pumpApp(
      MainnetMigrationScreen(onFinished: () => finished.add(true)),
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        testnetStatusProvider.overrideWith((ref) => status()),
      ],
    );
    await tester.pump();
    expect(find.text('Quantus is now on Mainnet!'), findsOneWidget);
    await tester.tap(find.byKey(const Key(E2EKeys.mainnetMigrationNextButton)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return (settings: settings, finished: finished);
  }

  testWidgets('a miner sees their block count and Done retires the notice', (tester) async {
    final flow = await pumpSecondPage(tester, () async => _miner);
    expect(find.text('Dear Testnet Miner'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(createWallet, findsNothing);

    await tester.tap(finish);
    await tester.pump();
    expect(flow.settings.migrationDone, isTrue);
    expect(flow.finished, [true]);
  });

  testWidgets('a holder can keep the wallet', (tester) async {
    final flow = await pumpSecondPage(tester, () async => _holder);
    expect(find.text('Dear Testnet User'), findsOneWidget);
    expect(find.text('Keep Wallet'), findsOneWidget);
    expect(createWallet, findsOneWidget);

    await tester.tap(finish);
    await tester.pump();
    expect(flow.settings.migrationDone, isTrue);
    expect(flow.finished, [true]);
  });

  testWidgets('a newcomer can migrate the old wallet, which keeps it as is', (tester) async {
    final flow = await pumpSecondPage(tester, () async => _newcomer);
    expect(find.text('Migrate Old Wallet'), findsOneWidget);
    expect(createWallet, findsOneWidget);

    await tester.tap(finish);
    await tester.pump();
    expect(flow.settings.migrationDone, isTrue);
    expect(flow.finished, [true]);
  });

  testWidgets('creating a new wallet goes through the reset confirmation', (tester) async {
    final flow = await pumpSecondPage(tester, () async => _newcomer);
    await tester.tap(createWallet);
    await tester.pumpAndSettle();
    expect(find.byType(ResetConfirmationScreen), findsOneWidget);
    expect(flow.settings.migrationDone, isFalse);
  });

  testWidgets('an unreachable testnet falls back to the holder page and says so', (tester) async {
    final flow = await pumpSecondPage(tester, () async => throw Exception('testnet down'));
    expect(find.text('Dear Testnet User'), findsOneWidget);
    expect(find.textContaining('could not be reached'), findsOneWidget);
    expect(find.text('Keep Wallet'), findsOneWidget);
    expect(flow.settings.migrationDone, isFalse);
  });

  testWidgets('Retry on the unreachable page runs the check again', (tester) async {
    var calls = 0;
    await pumpSecondPage(tester, () async {
      calls++;
      throw Exception('testnet down');
    });
    expect(calls, 1);
    await tester.tap(find.byKey(const Key(E2EKeys.mainnetMigrationRetryButton)));
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('a failed completion write keeps the notice open and says why', (tester) async {
    final flow = await pumpSecondPage(tester, () async => _newcomer, failWrite: true);
    await tester.tap(finish);
    await tester.pump();
    await tester.pump();
    expect(flow.finished, isEmpty);
    expect(flow.settings.migrationDone, isFalse);
    expect(find.textContaining('disk full'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('the second page waits on the check', (tester) async {
    await pumpSecondPage(tester, () => Completer<TestnetStatus>().future);
    expect(find.byType(Loader), findsOneWidget);
    expect(finish, findsNothing);
  });
}
