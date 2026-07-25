import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../support/app_launcher.dart';
import '../support/patrol_timeouts.dart';
import '../support/selectors.dart';
import '../support/wallet_flows.dart';

void main() {
  patrolTest('create wallet and view recovery phrase from settings', ($) async {
    await AppLauncher.launchFresh($);
    await WalletFlows.createFromWelcome($);

    await $(Selectors.homeSettingsButton).tap();
    await $(Selectors.settingsScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);

    await $(Selectors.settingsWalletMenuRow).tap();
    await $(Selectors.walletSettingsScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);

    await $(Selectors.walletSettingsRecoveryPhraseRow).tap();
    await $(Selectors.recoveryPhraseConfirmScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);

    await $(Selectors.recoveryPhraseConfirmContinueButton).tap();
    await $(Selectors.recoveryPhraseScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);

    await $(Selectors.recoveryPhraseRevealArea).waitUntilVisible(timeout: PatrolTimeouts.network);
    await $(Selectors.recoveryPhraseRevealArea).tap();

    expect($(Selectors.recoveryPhraseRevealed), findsOneWidget);
  });
}
