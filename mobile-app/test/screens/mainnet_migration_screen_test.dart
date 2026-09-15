import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/mainnet_migration_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mainnet_migration_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/receive/receive_screen.dart';
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

/// Never answers, so only a picked outcome can move the debug flow along.
class _SilentService extends Fake implements MainnetMigrationService {
  @override
  Future<TestnetStatus> checkTestnetStatus() => Completer<TestnetStatus>().future;
}

final _miner = TestnetStatus(blocksMined: 1234, balance: BigInt.zero);
final _holder = TestnetStatus(blocksMined: 0, balance: BigInt.from(7));
final _newcomer = TestnetStatus(blocksMined: 0, balance: BigInt.zero);

void main() {
  final keep = find.byKey(const Key(E2EKeys.mainnetMigrationKeepWalletButton));
  final createWallet = find.byKey(const Key(E2EKeys.mainnetMigrationCreateWalletButton));
  final getTokens = find.byKey(const Key(E2EKeys.mainnetMigrationGetTokensButton));
  final goToWallet = find.byKey(const Key(E2EKeys.mainnetMigrationGoToWalletButton));

  /// Lets the checking page's minimum time pass and the page turn finish.
  Future<void> turnPage(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<({_Settings settings, List<bool> finished})> pumpFlow(
    WidgetTester tester,
    Future<TestnetStatus> Function() status, {
    bool failWrite = false,
    bool debugPicker = false,
  }) async {
    final settings = _Settings()..failWrite = failWrite;
    final finished = <bool>[];
    await tester.pumpApp(
      MainnetMigrationScreen(onFinished: () => finished.add(true)),
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        debugMainnetMigrationProvider.overrideWithValue(debugPicker),
        if (debugPicker)
          mainnetMigrationServiceProvider.overrideWithValue(_SilentService())
        else
          testnetStatusProvider.overrideWith((ref) => status()),
      ],
    );
    await tester.pump();
    expect(find.text('Quantus is live on mainnet.'), findsOneWidget);
    return (settings: settings, finished: finished);
  }

  Future<({_Settings settings, List<bool> finished})> pumpOutcome(
    WidgetTester tester,
    Future<TestnetStatus> Function() status, {
    bool failWrite = false,
  }) async {
    final flow = await pumpFlow(tester, status, failWrite: failWrite);
    await turnPage(tester);
    return flow;
  }

  Future<void> keepWallet(WidgetTester tester) async {
    await tester.tap(keep);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the checking page turns into the outcome once testnet answers', (tester) async {
    await pumpFlow(tester, () async => _miner);
    await tester.pump(const Duration(milliseconds: 500));
    expect(keep, findsNothing);

    await turnPage(tester);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('Keep this wallet.'), findsOneWidget);
    expect(createWallet, findsNothing);
  });

  testWidgets('keeping the wallet retires the notice and the closing page opens the wallet', (tester) async {
    final flow = await pumpOutcome(tester, () async => _miner);
    await keepWallet(tester);
    expect(flow.settings.migrationDone, isTrue);
    expect(find.text("You're all set."), findsOneWidget);
    expect(flow.finished, isEmpty);

    await tester.tap(goToWallet);
    expect(flow.finished, [true]);
  });

  for (final (who, status) in [('a holder', _holder), ('a newcomer', _newcomer)]) {
    testWidgets('$who sees that nothing carried over and may start a new wallet', (tester) async {
      await pumpOutcome(tester, () async => status);
      expect(find.text('Nothing carried over.'), findsOneWidget);
      expect(keep, findsOneWidget);
      expect(createWallet, findsOneWidget);
    });
  }

  testWidgets('Get tokens retires the notice and opens the receive screen', (tester) async {
    final flow = await pumpOutcome(tester, () async => _holder);
    await keepWallet(tester);

    await tester.tap(getTokens);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(flow.finished, [true]);
    expect(find.byType(ReceiveScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('creating a new wallet asks first; keeping the wallet just closes the dialog', (tester) async {
    final flow = await pumpOutcome(tester, () async => _newcomer);
    await tester.tap(createWallet);
    await tester.pumpAndSettle();
    expect(find.text('Create a new wallet?'), findsOneWidget);
    expect(find.textContaining('This wallet stays on the device'), findsOneWidget);

    await tester.tap(find.text('Keep my wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Create a new wallet?'), findsNothing);
    expect(flow.settings.migrationDone, isFalse);
    expect(flow.finished, isEmpty);
  });

  testWidgets('an unreachable testnet says so and still lets the wallet be kept', (tester) async {
    final flow = await pumpOutcome(tester, () async => throw Exception('testnet down'));
    expect(find.text("We couldn't check this wallet."), findsOneWidget);
    expect(find.text("COULDN'T CHECK"), findsOneWidget);
    expect(createWallet, findsOneWidget);

    await keepWallet(tester);
    expect(flow.settings.migrationDone, isTrue);
    expect(find.text("You're all set."), findsOneWidget);
  });

  testWidgets('the unreachable confirmation recommends keeping the wallet', (tester) async {
    await pumpOutcome(tester, () async => throw Exception('testnet down'));
    await tester.tap(createWallet);
    await tester.pumpAndSettle();

    QuantusButton button(String label) =>
        tester.widget(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));
    expect(find.text("We couldn't check this wallet"), findsOneWidget);
    expect(find.textContaining('trying again later'), findsOneWidget);
    expect(button('Keep my wallet').variant, ButtonVariant.primary);
    expect(button('Create new wallet').variant, ButtonVariant.staged);
  });

  testWidgets('a failed completion write keeps the notice open and says why', (tester) async {
    final flow = await pumpOutcome(tester, () async => _newcomer, failWrite: true);
    await keepWallet(tester);
    expect(flow.finished, isEmpty);
    expect(flow.settings.migrationDone, isFalse);
    expect(find.textContaining('disk full'), findsOneWidget);
    expect(find.text("You're all set."), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('the checking page waits on the check', (tester) async {
    await pumpFlow(tester, () => Completer<TestnetStatus>().future);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('READING TESTNET HISTORY'), findsOneWidget);
    expect(keep, findsNothing);
  });

  testWidgets('debug builds hold the checking page until an outcome is picked', (tester) async {
    await pumpFlow(tester, () async => _miner, debugPicker: true);
    await tester.pump(const Duration(seconds: 3));
    expect(keep, findsNothing);
    for (final outcome in debugTestnetOutcomes) {
      expect(find.text(outcome), findsOneWidget);
    }

    await tester.tap(find.text('error'));
    await tester.pump();
    await turnPage(tester);
    expect(find.text("We couldn't check this wallet."), findsOneWidget);
  });
}
