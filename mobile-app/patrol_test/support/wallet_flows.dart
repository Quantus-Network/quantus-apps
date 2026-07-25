import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_timeouts.dart';
import 'selectors.dart';
import 'test_env.dart';

/// Shared onboarding flows for Patrol E2E tests.
class WalletFlows {
  WalletFlows._();

  /// Creates a new wallet from the welcome screen and waits for home.
  static Future<void> createFromWelcome(PatrolIntegrationTester $) async {
    expect($(Selectors.welcomeScreen), findsOneWidget);

    await $(Selectors.welcomeCreateWalletButton).tap();

    await $(Selectors.accountReadyDoneButton).waitUntilVisible(timeout: PatrolTimeouts.network);
    await $(Selectors.accountReadyDoneButton).tap();

    await $(Selectors.homeScreen).waitUntilVisible(timeout: PatrolTimeouts.network);
  }

  /// Imports a wallet from the welcome screen and waits for home.
  static Future<void> importFromWelcome(PatrolIntegrationTester $) async {
    expect($(Selectors.welcomeScreen), findsOneWidget);

    await $(Selectors.welcomeImportWalletButton).tap();

    await $(Selectors.importWalletScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);

    await $(Selectors.importWalletSeedPhraseField).enterText(TestEnv.importMnemonic);

    await $(Selectors.importWalletButton).tap();

    await $(Selectors.homeScreen).waitUntilVisible(timeout: PatrolTimeouts.network);
  }
}
