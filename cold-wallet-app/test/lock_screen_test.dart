import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/app.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/root_gate.dart';
import 'package:quantus_cold_wallet/screens/welcome_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Outcome { unlocks, cancelled, keyLost }

class _LockedController extends WalletController {
  _LockedController(this.outcome);

  final _Outcome outcome;
  int attempts = 0;
  bool wiped = false;

  @override
  WalletState build() => const WalletState(status: WalletStatus.locked, biometricEnabled: true);

  @override
  Future<bool> unlockWithBiometric() async {
    attempts++;
    switch (outcome) {
      case _Outcome.unlocks:
        state = const WalletState(status: WalletStatus.unlocked, mnemonic: 'm', biometricEnabled: true);
        return true;
      case _Outcome.cancelled:
        state = state.copyWith(error: unlockCancelledError);
        return false;
      case _Outcome.keyLost:
        state = state.copyWith(biometricEnabled: false, error: 'This device can no longer open the wallet.');
        return false;
    }
  }

  @override
  Future<void> wipe() async {
    wiped = true;
    state = const WalletState(status: WalletStatus.needsSetup);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpLockScreen(WidgetTester tester, _LockedController controller) async {
    FlutterSecureStorage.setMockInitialValues({});
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletControllerProvider.overrideWith(() => controller)],
        child: Builder(
          builder: (context) => MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.darkTheme(context),
            home: LockScreen(navigatorKey: navigatorKey),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('asks the device to unlock as soon as it appears', (tester) async {
    final controller = _LockedController(_Outcome.unlocks);
    await pumpLockScreen(tester, controller);

    expect(controller.attempts, 1);
  });

  testWidgets('a cancelled prompt is said so; Unlock retries', (tester) async {
    final controller = _LockedController(_Outcome.cancelled);
    await pumpLockScreen(tester, controller);
    await tester.pump();

    final title = tester.widget<Text>(find.text('Locked'));
    expect(title.style?.fontSize, text.titleHero.fontSize);
    expect(title.style?.color, colors.textContent);
    expect(find.byType(QuantusIcon), findsOneWidget);
    final hint = tester.widget<Text>(find.text('Unlock cancelled. Tap Unlock to try again.'));
    expect(hint.style?.color, colors.textMuted);
    expect(find.text('Reset wallet…'), findsNothing);

    await tester.tap(find.text('Unlock'));
    await tester.pump();
    expect(controller.attempts, 2);
  });

  testWidgets('coming back from the background prompts again', (tester) async {
    final controller = _LockedController(_Outcome.cancelled);
    await pumpLockScreen(tester, controller);
    await tester.pump();
    expect(controller.attempts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(controller.attempts, 2);
  });

  testWidgets('a key the device can no longer release offers the reset', (tester) async {
    final controller = _LockedController(_Outcome.keyLost);
    await pumpLockScreen(tester, controller);
    await tester.pump();

    final error = tester.widget<Text>(find.text('This device can no longer open the wallet.'));
    expect(error.style?.color, colors.semanticEmber);

    await tester.tap(find.text('Reset wallet…'));
    await tester.pumpAndSettle();
    expect(find.text('Reset wallet?'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(controller.wiped, isTrue);
  });

  testWidgets('in the app the overlay sits beside the Navigator; reset still confirms and lands on Welcome', (
    tester,
  ) async {
    final controller = _LockedController(_Outcome.keyLost);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletControllerProvider.overrideWith(() => controller),
          isOnlineProvider.overrideWith((ref) => false),
        ],
        child: const ColdWalletApp(),
      ),
    );
    await tester.pump();
    // The route the wallet was on when it locked, under the overlay.
    Navigator.push(
      tester.element(find.byType(RootGate)),
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('pushed'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);
    expect(find.byType(LockScreen), findsOneWidget);

    await tester.tap(find.text('Reset wallet…'));
    await tester.pumpAndSettle();
    expect(find.text('Reset wallet?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset wallet?'), findsNothing);
    expect(controller.wiped, isFalse);

    await tester.tap(find.text('Reset wallet…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(controller.wiped, isTrue);
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text('pushed'), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
