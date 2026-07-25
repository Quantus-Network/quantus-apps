import 'package:flutter/widgets.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';

/// Stable widget [Key]s used by the E2E tests.
///
/// Selecting by key keeps tests independent of locale and copy changes. The key
/// strings come from [E2EKeys] in `lib/`, which the production widgets use too,
/// so the test selectors and the app can never drift apart.
class Selectors {
  Selectors._();

  static const Key welcomeScreen = Key(E2EKeys.welcomeScreen);
  static const Key welcomeCreateWalletButton = Key(E2EKeys.welcomeCreateWalletButton);
  static const Key welcomeImportWalletButton = Key(E2EKeys.welcomeImportWalletButton);

  static const Key accountReadyDoneButton = Key(E2EKeys.accountReadyDoneButton);

  static const Key importWalletScreen = Key(E2EKeys.importWalletScreen);
  static const Key importWalletSeedPhraseField = Key(E2EKeys.importWalletSeedPhraseField);
  static const Key importWalletButton = Key(E2EKeys.importWalletButton);

  static const Key homeScreen = Key(E2EKeys.homeScreen);
  static const Key homeSendButton = Key(E2EKeys.homeSendButton);
  static const Key homeSettingsButton = Key(E2EKeys.homeSettingsButton);
  static const Key homePendingSendActivityItem = Key(E2EKeys.homePendingSendActivityItem);

  static const Key settingsScreen = Key(E2EKeys.settingsScreen);
  static const Key settingsWalletMenuRow = Key(E2EKeys.settingsWalletMenuRow);

  static const Key walletSettingsScreen = Key(E2EKeys.walletSettingsScreen);
  static const Key walletSettingsRecoveryPhraseRow = Key(E2EKeys.walletSettingsRecoveryPhraseRow);

  static const Key recoveryPhraseConfirmScreen = Key(E2EKeys.recoveryPhraseConfirmScreen);
  static const Key recoveryPhraseConfirmContinueButton = Key(E2EKeys.recoveryPhraseConfirmContinueButton);
  static const Key recoveryPhraseScreen = Key(E2EKeys.recoveryPhraseScreen);
  static const Key recoveryPhraseRevealArea = Key(E2EKeys.recoveryPhraseRevealArea);
  static const Key recoveryPhraseRevealed = Key(E2EKeys.recoveryPhraseRevealed);

  static const Key sendSelectRecipientScreen = Key(E2EKeys.sendSelectRecipientScreen);
  static const Key sendRecipientField = Key(E2EKeys.sendRecipientField);
  static const Key sendContinueButton = Key(E2EKeys.sendContinueButton);

  static const Key sendInputAmountScreen = Key(E2EKeys.sendInputAmountScreen);
  static const Key sendAmountField = Key(E2EKeys.sendAmountField);
  static const Key sendReviewButton = Key(E2EKeys.sendReviewButton);

  static const Key sendReviewScreen = Key(E2EKeys.sendReviewScreen);
  static const Key sendConfirmButton = Key(E2EKeys.sendConfirmButton);

  static const Key sendTxSubmittedScreen = Key(E2EKeys.sendTxSubmittedScreen);
  static const Key sendTxSubmittedDoneButton = Key(E2EKeys.sendTxSubmittedDoneButton);
}
