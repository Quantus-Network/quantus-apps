import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../support/app_launcher.dart';
import '../support/patrol_timeouts.dart';
import '../support/selectors.dart';
import '../support/send_preflight.dart';
import '../support/test_env.dart';
import '../support/text_input.dart';
import '../support/wallet_flows.dart';

Future<void> _openReviewSend(PatrolIntegrationTester $) async {
  final deadline = DateTime.now().add(PatrolTimeouts.network);
  while (DateTime.now().isBefore(deadline)) {
    await $(Selectors.sendReviewButton).tap();
    await $.pump(const Duration(milliseconds: 800));
    if ($(Selectors.sendReviewScreen).evaluate().isNotEmpty) {
      return;
    }
  }
  await $(Selectors.sendReviewScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);
}

void main() {
  patrolTest('import wallet and send minimal amount shows pending activity', ($) async {
    if (!await $.platform.mobile.isVirtualDevice()) {
      throw StateError(
        'send_flow_test runs on simulator/emulator only. '
        'Use patrol_ios_simulator.sh or patrol_android_emulator.sh.',
      );
    }

    await AppLauncher.launchFresh($);
    await WalletFlows.importFromWelcome($);

    final send = await SendPreflight.assertFundedAndGetMinimalSend(
      recipientAddress: TestEnv.sendRecipientAddress,
    );

    await $(Selectors.homeSendButton).tap();
    await $(Selectors.sendSelectRecipientScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);

    await $(Selectors.sendRecipientField).enterText(TestEnv.sendRecipientAddress);
    await $(Selectors.sendContinueButton).tap();

    await $(Selectors.sendInputAmountScreen).waitUntilVisible(timeout: PatrolTimeouts.network);
    await typeTextIntoField($, Selectors.sendAmountField, send.amountText);
    // Fee refresh is debounced on the amount screen.
    await $.pump(const Duration(milliseconds: 600));
    await _openReviewSend($);

    await $(Selectors.sendConfirmButton).tap();

    await $(Selectors.sendTxSubmittedScreen).waitUntilVisible(timeout: PatrolTimeouts.transaction);

    await $(Selectors.sendTxSubmittedDoneButton).tap();
    await $(Selectors.homeScreen).waitUntilVisible(timeout: PatrolTimeouts.visible);

    await $(Selectors.homePendingSendActivityItem).scrollTo();
    await $(Selectors.homePendingSendActivityItem).waitUntilVisible(timeout: PatrolTimeouts.network);
  });
}
