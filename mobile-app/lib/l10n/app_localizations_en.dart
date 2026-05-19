// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get walletInitErrorTitle => 'Wallet Error';

  @override
  String get walletInitErrorMessage => 'Unable to find secret phrase. Please restore your wallet.';

  @override
  String get walletInitErrorButtonLabel => 'OK';

  @override
  String get authUseDeviceBiometricsToUnlock => 'Use device biometrics to unlock';

  @override
  String get authAuthenticating => 'Authenticating...';

  @override
  String get authUnlockWallet => 'Unlock Wallet';

  @override
  String get authAuthorizationRequired => 'Authorization \n Required';

  @override
  String get welcomeTagline => 'Quantum Secure Encrypted Money';

  @override
  String get welcomeCreateNewWallet => 'Create New Wallet';

  @override
  String get welcomeImportWallet => 'Import Wallet';

  @override
  String get createWalletAppBarTitle => 'Create Wallet';

  @override
  String get createWalletCautionHeadline => 'Keep your Recovery Phrase Secret';

  @override
  String get createWalletCautionBullet1 => 'If you lose this device, your recovery phrase is the only way back';

  @override
  String get createWalletCautionBullet2 =>
      'Anyone who gets hold of it has complete control over your funds, permanently';

  @override
  String get createWalletCautionBullet3 => 'Write it down and keep it somewhere safe. Do not save it digitally';

  @override
  String get createWalletCautionCheckboxLabel =>
      'I understand that anyone with my recovery phrase can access my wallet. I will store it safely.';

  @override
  String get createWalletCautionContinue => 'Continue';

  @override
  String get createWalletRecoveryPhraseNext => 'Next';

  @override
  String createWalletRecoveryPhraseFailedGenerate(String error) {
    return 'Failed to generate: $error';
  }

  @override
  String createWalletRecoveryPhraseSaveError(String error) {
    return 'Error saving wallet: $error';
  }

  @override
  String get recoveryPhraseBodyInstructions =>
      'Write these words down in order and keep them somewhere only you can access. Do not screenshot or copy to a notes app.';

  @override
  String get recoveryPhraseBodyCopy => 'Copy';

  @override
  String get recoveryPhraseBodyCopiedMessage => 'Recovery phrase copied to clipboard';

  @override
  String get accountReadyAccountCreated => 'Account Created';

  @override
  String get accountReadyWalletCreated => 'Wallet Created';

  @override
  String get accountReadyWalletImported => 'Wallet Imported';

  @override
  String get accountReadyDone => 'Done';

  @override
  String get importWalletAppBarTitle => 'Import Wallet';

  @override
  String get importWalletDescription => 'Restore an existing wallet with your 12 or 24 words recovery phrase';

  @override
  String get importWalletHint => 'Type in or paste your recovery phrase. Separate words with spaces.';

  @override
  String get importWalletButton => 'Import';

  @override
  String get importWalletValidationError => 'Recovery phrase must be 12 or 24 words';

  @override
  String homeError(String error) {
    return 'Error: $error';
  }

  @override
  String get homeNoActiveAccount => 'No active account';

  @override
  String get homeCharge => 'Charge';

  @override
  String get homeGetTestnetTokens => 'Get Testnet Tokens ↗';

  @override
  String get homeErrorLoadingBalance => 'Error loading balance';

  @override
  String get homeReceive => 'Receive';

  @override
  String get homeSend => 'Send';

  @override
  String get homeSwap => 'Swap';

  @override
  String get homeActivityTitle => 'Activity';

  @override
  String get homeActivityViewAll => 'View All';

  @override
  String get homeActivityErrorLoading => 'Error loading transactions';

  @override
  String get homeActivityRetry => 'Retry';

  @override
  String get homeActivityEmptyTitle => 'No Transactions Yet';

  @override
  String get homeActivityEmptyMessage => 'Your activity will appear here once you send or receive QUAN.';
}
