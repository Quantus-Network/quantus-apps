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
  String get createWalletCautionHeadline => 'Keep your Recovery Phrase Secret';

  @override
  String get createWalletCautionBullet1 => 'If you lose this device, your recovery phrase is the only way back';

  @override
  String get createWalletCautionBullet2 =>
      'Anyone who gets hold of it has complete control over your funds, permanently';

  @override
  String get createWalletCautionBullet3 => 'Write it down and keep it somewhere safe. Do not save it digitally';

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
  String get recoveryPhraseBodyTapToReveal => 'Tap to reveal';

  @override
  String get recoveryPhraseBodyTapToHide => 'Tap to hide';

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
  String get homeBackupReminder => 'Back up your recovery phrase';

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

  @override
  String get accountsSheetTitle => 'Accounts';

  @override
  String get accountsSheetFailedLoadAccounts => 'Failed to load accounts.';

  @override
  String get accountsSheetFailedLoadActiveAccount => 'Failed to load active account.';

  @override
  String get accountsSheetNoAccountsFound => 'No accounts found.';

  @override
  String get accountsSheetAddAccount => 'Add Account';

  @override
  String get accountsSheetBalanceUnavailable => 'Balance unavailable';

  @override
  String accountsSheetBalance(String balance, String symbol) {
    return '$balance $symbol';
  }

  @override
  String get addAccountMenuTitle => 'Add Account';

  @override
  String get addAccountMenuCreateTitle => 'Create New Account';

  @override
  String get addAccountMenuCreateSubtitle => 'Generate a fresh wallet address';

  @override
  String get addAccountMenuImportTitle => 'Import Wallet';

  @override
  String get addAccountMenuImportSubtitle => 'Use a recovery phrase to import';

  @override
  String get createAccountAppBarTitle => 'Account Name';

  @override
  String get createAccountSubtitle => 'Give this account a name you\'ll recognize. You can change it anytime.';

  @override
  String get createAccountButton => 'Create';

  @override
  String get createAccountErrorCouldNotAdd => 'Could not add account.';

  @override
  String createAccountDefaultName(int number) {
    return 'Account $number';
  }

  @override
  String get editAccountAppBarTitle => 'Account Name';

  @override
  String get editAccountDone => 'Done';

  @override
  String get editAccountNameEmpty => 'Account name can\'t be empty';

  @override
  String get editAccountRenameFailed => 'Failed to rename account.';

  @override
  String get accountMenuTitle => 'Accounts';

  @override
  String get accountMenuAccountName => 'Account Name';

  @override
  String get accountMenuAddressDetails => 'Address Details';

  @override
  String get accountMenuShowRecoveryPhrase => 'Show Recovery Phrase';

  @override
  String get accountMenuNotFound => 'Account not found';

  @override
  String get accountDetailsTitle => 'Address Details';

  @override
  String get addHardwareAccountAddWallet => 'Add Hardware Wallet';

  @override
  String get addHardwareAccountAddAccount => 'Add Hardware Account';

  @override
  String get addHardwareAccountNameLabel => 'NAME';

  @override
  String get addHardwareAccountNameHintWallet => 'Hardware Wallet';

  @override
  String get addHardwareAccountNameHintAccount => 'Account';

  @override
  String get addHardwareAccountAddressLabel => 'ADDRESS';

  @override
  String get addHardwareAccountAddressHint => 'SS58 address';

  @override
  String get addHardwareAccountDebugFill => 'Debug Fill';

  @override
  String get addHardwareAccountNameRequired => 'Name is required';

  @override
  String get addHardwareAccountInvalidAddress => 'Invalid address';

  @override
  String get sendTitle => 'Send';

  @override
  String get sendPayTitle => 'Pay';

  @override
  String get sendEnterAddress => 'Enter Address';

  @override
  String get sendSelectRecipientSendTo => 'Send To';

  @override
  String sendSelectRecipientSearchHint(String symbol) {
    return 'Enter $symbol Address';
  }

  @override
  String get sendSelectRecipientScanTitle => 'Scan QR code';

  @override
  String sendSelectRecipientScanSubtitle(String symbol) {
    return 'Tap to scan a $symbol Address';
  }

  @override
  String get sendSelectRecipientRecents => 'Recents';

  @override
  String get sendSelectRecipientContinue => 'Continue';

  @override
  String get sendInputAmountSendTo => 'SEND TO';

  @override
  String get sendInputAmountAvailableBalance => 'Available Balance:';

  @override
  String get sendInputAmountNetworkFee => 'Network Fee:';

  @override
  String get sendInputAmountMax => 'Max';

  @override
  String get sendInputAmountInvalidAmount => 'Please enter a valid amount';

  @override
  String get sendInputAmountChecksumRequired => 'Recipient checksum is required';

  @override
  String get sendReviewSending => 'SENDING';

  @override
  String get sendReviewTo => 'TO';

  @override
  String get sendReviewAmount => 'AMOUNT';

  @override
  String get sendReviewNetworkFee => 'NETWORK FEE';

  @override
  String get sendReviewYouPay => 'YOU PAY';

  @override
  String get sendReviewConfirm => 'Confirm';

  @override
  String get sendReviewAuthReason => 'Authenticate to confirm transaction';

  @override
  String get sendReviewAuthRequired => 'Authentication required to send';

  @override
  String get sendReviewSubmitFailed => 'Failed submitting transaction';

  @override
  String sendTxSubmittedHeadlinePaid(String amount, String symbol) {
    return '$amount $symbol paid';
  }

  @override
  String sendTxSubmittedHeadlineSent(String amount, String symbol) {
    return '$amount $symbol sent';
  }

  @override
  String get sendTxSubmittedOnItsWay => 'On its way';

  @override
  String get sendTxSubmittedToLabel => 'To';

  @override
  String get sendTxSubmittedDone => 'Done';

  @override
  String get sendLogicCantSelfTransfer => 'Can\'t Self Transfer';

  @override
  String get sendLogicEnterAmount => 'Enter Amount';

  @override
  String get sendLogicInvalidAmount => 'Invalid Amount';

  @override
  String get sendLogicBelowExistentialDeposit => 'Below Existential Deposit';

  @override
  String get sendLogicInsufficientBalance => 'Insufficient Balance';

  @override
  String get sendLogicReviewSend => 'Review Send';

  @override
  String get activityTitle => 'Activity';

  @override
  String activityError(String error) {
    return 'Error: $error';
  }

  @override
  String get activityNoAccount => 'No account';

  @override
  String get activityEmpty => 'No transactions yet';

  @override
  String get activityFilterAll => 'All';

  @override
  String get activityFilterSend => 'Send';

  @override
  String get activityFilterReceive => 'Receive';

  @override
  String get activityDateToday => 'Today';

  @override
  String get activityDateYesterday => 'Yesterday';

  @override
  String get activityTxSending => 'Sending';

  @override
  String get activityTxReceiving => 'Receiving';

  @override
  String get activityTxPending => 'Pending';

  @override
  String get activityTxSent => 'Sent';

  @override
  String get activityTxReceived => 'Received';

  @override
  String get activityTxTo => 'To';

  @override
  String get activityTxFrom => 'From';

  @override
  String get activityTxTimeNow => 'now';

  @override
  String activityTxTimeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String activityTxTimeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String activityTxTimeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String activityTxTimeRemaining(String days, String hours, String minutes) {
    return '${days}d:${hours}h:${minutes}m';
  }

  @override
  String get activityDetailTitleSending => 'Sending';

  @override
  String get activityDetailTitleScheduled => 'Scheduled';

  @override
  String get activityDetailTitleReceiving => 'Receiving';

  @override
  String get activityDetailTitleSent => 'Sent';

  @override
  String get activityDetailTitleReceived => 'Received';

  @override
  String get activityDetailStatusInProcess => 'In Process';

  @override
  String get activityDetailStatusScheduled => 'Scheduled';

  @override
  String get activityDetailStatusCompleted => 'Completed';

  @override
  String get activityDetailStatus => 'STATUS';

  @override
  String get activityDetailTo => 'TO';

  @override
  String get activityDetailFrom => 'FROM';

  @override
  String get activityDetailDate => 'DATE';

  @override
  String get activityDetailNetworkFee => 'NETWORK FEE';

  @override
  String get activityDetailTxHash => 'TX HASH';

  @override
  String get activityDetailViewExplorer => 'View in Explorer ↗';

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receiveTabQrCode => 'QR Code';

  @override
  String get receiveTabAddress => 'Address';

  @override
  String get receiveCopy => 'Copy';

  @override
  String receiveErrorLoadingAccount(String error) {
    return 'Error loading account data: $error';
  }

  @override
  String receiveClipboardContent(String accountId, String checksum) {
    return 'Account Id:\n$accountId\n\nCheckphrase:\n$checksum';
  }

  @override
  String get receiveCopiedMessage => 'Account details copied to clipboard';

  @override
  String get posAmountTitle => 'New Charge';

  @override
  String posAmountCharge(String amount) {
    return 'Charge $amount';
  }

  @override
  String get posAmountEnterAmount => 'Enter Amount';

  @override
  String get posQrTitleScanToPay => 'Scan to Pay';

  @override
  String get posQrTitlePaymentReceived => 'Payment Received';

  @override
  String posQrError(String error) {
    return 'Error: $error';
  }

  @override
  String get posQrNoActiveAccount => 'No active account';

  @override
  String get posQrInvalidAmount => 'Invalid amount. Tap to retry.';

  @override
  String get posQrConnectionLost => 'Connection lost. Tap to retry.';

  @override
  String get posQrTimedOut => 'Timed out. Tap to retry.';

  @override
  String get posQrNewCharge => 'New Charge';

  @override
  String get posQrDone => 'Done';

  @override
  String posQrAmountReceived(String amount) {
    return '$amount received';
  }

  @override
  String get posQrFrom => 'From:';

  @override
  String get posQrWaitingForPayment => 'Waiting for payment';

  @override
  String get posQrNetworkError => 'Network Error';

  @override
  String get posQrTryAgain => 'Try Again';

  @override
  String posQrPaidAt(String time) {
    return 'At $time';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsWalletTitle => 'Wallet';

  @override
  String get settingsWalletSubtitle => 'Recovery Phrase, Reset Wallet';

  @override
  String get settingsPreferencesTitle => 'Preferences';

  @override
  String get settingsPreferencesSubtitle => 'Language, currency, POS mode, notifications';

  @override
  String get settingsMiningRewards => 'Mining Rewards';

  @override
  String settingsMiningRewardsSubtitle(int count) {
    return '$count blocks mined';
  }

  @override
  String get settingsMiningRewardsError => 'Error getting mining rewards';

  @override
  String get settingsAccountTypeTitle => 'Account Type';

  @override
  String get settingsAccountTypeSubtitle => 'Advanced Account Features';

  @override
  String get settingsHelpTitle => 'Help & Support';

  @override
  String get settingsHelpSubtitle => 'FAQs, Contact the team';

  @override
  String get settingsAboutTitle => 'About Quantus';

  @override
  String settingsAboutHubSubtitle(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get settingsWalletRecoveryPhrase => 'Recovery Phrase';

  @override
  String get settingsWalletRecoveryPhraseSubtitle => 'View your 24-word Backup Password';

  @override
  String get settingsWalletReset => 'Reset Wallet';

  @override
  String get settingsWalletResetSubtitle => 'Removes all data from this device';

  @override
  String get settingsWalletNoWalletsFound => 'No wallets found';

  @override
  String get settingsWalletFailedToLoad => 'Failed to load wallets';

  @override
  String get settingsSelectWalletTitle => 'Select Wallet';

  @override
  String get settingsSelectWalletNoWallets => 'No wallets found';

  @override
  String settingsSelectWalletItem(int number) {
    return 'Wallet $number';
  }

  @override
  String get settingsRecoveryConfirmAuthReason => 'Authenticate to see recovery phrase';

  @override
  String get settingsRecoveryConfirmAuthRequired => 'Authentication required to see recovery phrase';

  @override
  String get settingsRecoveryPhraseTitle => 'Recovery Phrase';

  @override
  String get settingsRecoveryPhraseDone => 'Done';

  @override
  String get settingsResetTitle => 'Reset Wallet';

  @override
  String get settingsResetAuthReason => 'Authenticate to reset wallet';

  @override
  String settingsResetFailed(String error) {
    return 'Failed to reset wallet: $error';
  }

  @override
  String get settingsResetAuthRequired => 'Authentication required to reset wallet';

  @override
  String get settingsResetCautionHeadline => 'This will erase\nyour wallet';

  @override
  String get settingsResetCautionBullet1 => 'All wallet data will be permanently removed from this device';

  @override
  String get settingsResetCautionBullet2 =>
      'Your funds stay on the blockchain but only your recovery phrase can restore access';

  @override
  String get settingsResetCautionBullet3 => 'Without it, your funds are gone forever';

  @override
  String get settingsResetCautionCheckbox => 'I\'ve backed up my recovery phrase';

  @override
  String get settingsPreferencesCurrency => 'Currency';

  @override
  String get settingsPreferencesCurrencySubtitle => 'Fiat display preference';

  @override
  String get settingsPreferencesLanguage => 'Language';

  @override
  String get settingsPreferencesLanguageSubtitle => 'App display language';

  @override
  String get settingsPreferencesPosMode => 'POS Mode';

  @override
  String get settingsPreferencesPosModeSubtitle => 'Point of sale features';

  @override
  String get settingsPreferencesNotifications => 'Notifications';

  @override
  String get settingsPreferencesNotificationsSubtitle => 'Transaction and wallet alerts';

  @override
  String get settingsCurrencyTitle => 'Currency';

  @override
  String get settingsCurrencySearchHint => 'Search';

  @override
  String get settingsCurrencyNoMatch => 'No currencies match your search';

  @override
  String settingsCurrencyError(String error) {
    return 'Error selecting currency: $error';
  }

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSearchHint => 'Search';

  @override
  String get settingsLanguageNoMatch => 'No languages match your search';

  @override
  String settingsLanguageError(String error) {
    return 'Error selecting language: $error';
  }

  @override
  String get settingsMiningTitle => 'Mining Rewards';

  @override
  String get settingsMiningRedeem => 'Redeem';

  @override
  String get settingsMiningStatusMining => 'Mining';

  @override
  String get settingsMiningStatusPending => 'Pending';

  @override
  String get settingsMiningBlocksMined => 'BLOCKS MINED';

  @override
  String get settingsMiningBlocksAcrossTestnets => 'blocks across all testnets';

  @override
  String get settingsMiningStatTestnetBlocks => 'TESTNET BLOCKS';

  @override
  String get settingsMiningStatTestnetRewards => 'TESTNET REWARDS';

  @override
  String get settingsMiningStatRedeemed => 'REDEEMED';

  @override
  String get settingsMiningStatRedeemable => 'REDEEMABLE';

  @override
  String get settingsMiningQuanEarned => 'QUAN EARNED';

  @override
  String get settingsMiningViewTelemetry => 'View Telemetry ↗';

  @override
  String get settingsMiningNoDataTitle => 'No mining data yet';

  @override
  String get settingsMiningNoDataBody => 'Set up a Quantus mining node to start earning rewards.';

  @override
  String get settingsMiningSetupGuide => 'Mining Setup Guide ↗';

  @override
  String get settingsMiningLoadError => 'Failed to load mining rewards';

  @override
  String get settingsMiningCheckConnection => 'Please check your connection';

  @override
  String get settingsMiningTestnetBlocks => 'blocks';

  @override
  String get settingsMiningDiracSince => 'Nov 2025';

  @override
  String get settingsMiningSchrodingerSince => 'Oct 2025';

  @override
  String get settingsMiningResonanceSince => 'Jul 2025';

  @override
  String get settingsTestnetTitle => 'Testnet Rewards';

  @override
  String get settingsTestnetLoadError => 'Failed to load testnet rewards';

  @override
  String settingsTestnetTotalBlocks(int count) {
    return '$count blocks';
  }

  @override
  String get settingsTestnetTotalDescription => 'Total blocks mined across all testnets';

  @override
  String get settingsTestnetBreakdown => 'Breakdown';

  @override
  String settingsTestnetRowBlocks(int count) {
    return '$count blocks';
  }

  @override
  String get settingsHelpScreenTitle => 'Help & Support';

  @override
  String get settingsHelpEmail => 'Email Support';

  @override
  String get settingsHelpTelegram => 'Telegram';

  @override
  String get settingsAboutScreenTitle => 'About';

  @override
  String get settingsAboutIntro =>
      'Quantus is a Layer 1 blockchain secured by ML-DSA Dilithium-5, the gold standard in quantum-resistant encryption. Built for a future where classical cryptography is no longer enough. Post-quantum cryptography for everyone.';

  @override
  String get settingsAboutTerms => 'Terms of Service';

  @override
  String get settingsAboutTermsSubtitle => 'quantus.com/terms/';

  @override
  String get settingsAboutPrivacy => 'Privacy policy';

  @override
  String get settingsAboutPrivacySubtitle => 'quantus.com/privacy-policy/';

  @override
  String get settingsAboutWebsite => 'Visit Website';

  @override
  String get settingsAboutWebsiteSubtitle => 'quantus.com';

  @override
  String settingsAboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get settingsAccountTypeScreenTitle => 'Account Type';

  @override
  String get settingsAccountTypeIntro =>
      'Advanced account features are coming soon. These will give you greater control over how transactions are authorised and secured.';

  @override
  String get settingsAccountTypeReversibleTitle => 'Reversible Transactions';

  @override
  String get settingsAccountTypeReversibleSubtitle => 'Reverse your sends within a time window';

  @override
  String get settingsAccountTypeHighSecurityTitle => 'High Security Account';

  @override
  String get settingsAccountTypeHighSecuritySubtitle => 'Guardian approval required';

  @override
  String get settingsAccountTypeMultiSigTitle => 'Multi-Signature';

  @override
  String get settingsAccountTypeMultiSigSubtitle => 'Multiple approvals required';

  @override
  String get settingsAccountTypeHardwareTitle => 'Hardware Wallet';

  @override
  String get settingsAccountTypeHardwareSubtitle => 'Pair a hardware device';

  @override
  String get settingsAccountTypeComingSoon => 'Coming Soon';

  @override
  String get swapTitle => 'Swap';

  @override
  String get swapFrom => 'From';

  @override
  String get swapTo => 'To';

  @override
  String get swapRefundAddress => 'Refund Address';

  @override
  String swapRefundAddressHint(String network) {
    return '$network Address';
  }

  @override
  String get swapSlippageTolerance => 'Slippage Tolerance';

  @override
  String get swapRate => 'Rate';

  @override
  String get swapGetQuote => 'Get a Quote';

  @override
  String swapRateLabel(String amount, String symbol) {
    return '1 QUAN = $amount $symbol';
  }

  @override
  String swapRateZero(String symbol) {
    return '1 QUAN = 0 $symbol';
  }

  @override
  String get swapTokenPickerTitle => 'Select Token';

  @override
  String get swapTokenPickerLoadError => 'Failed to load tokens';

  @override
  String get swapReviewTitle => 'Review Quote';

  @override
  String get swapReviewTotalFees => 'Total fees';

  @override
  String get swapReviewTotalAmount => 'Total Amount';

  @override
  String swapReviewSlippageWarning(String amount, String percent) {
    return 'You could receive up to \$$amount less based on the $percent% slippage you set';
  }

  @override
  String get swapReviewConfirm => 'Confirm';

  @override
  String get swapDepositAmount => 'Deposit Amount';

  @override
  String get swapDepositAmountCopied => 'Deposit amount copied to clipboard';

  @override
  String get swapDepositDemoWarning => 'For demo purposes only - do not send funds!';

  @override
  String get swapDepositShareQr => 'Share QR';

  @override
  String swapDepositShareContent(String network, String token, String address) {
    return 'Network: $network\nToken: $token\nAddress: $address';
  }

  @override
  String swapDepositNotice(String symbol, String network) {
    return 'Use your $symbol or $network wallet to deposit funds. Depositing other assets may result in loss of funds.';
  }

  @override
  String get swapDepositProcessingTitle => 'Processing Swap';

  @override
  String get swapDepositProcessingBody => 'This may take a few minutes...';

  @override
  String get swapDepositCompleteTitle => 'Swap Complete';

  @override
  String swapDepositCompleteBody(String amount) {
    return 'Your swap for $amount QUAN is complete.';
  }

  @override
  String get swapDepositTestnetBanner => 'DEMO ONLY - WE ARE STILL ON TESTNET';

  @override
  String get swapDepositSentFunds => 'I\'ve sent the funds';

  @override
  String get swapDepositDone => 'Done';

  @override
  String get swapRefundPickerTitle => 'Refund Addresses';

  @override
  String get swapRefundPickerEmpty => 'No recent refund addresses';

  @override
  String get componentQrScannerTitle => 'Scan QR Code';

  @override
  String get componentQrScannerNoCode => 'No QR code found in image';

  @override
  String get componentShare => 'Share';

  @override
  String get componentAddressLabel => 'ADDRESS';

  @override
  String get componentCheckphraseLabel => 'CHECKPHRASE';

  @override
  String get componentCheckphraseCopied => 'Checkphrase copied';

  @override
  String get componentNameFieldHint => 'Enter a name for your account';

  @override
  String get commonLoading => 'Loading...';

  @override
  String commonAmountBalance(String balance, String symbol) {
    return '$balance $symbol';
  }

  @override
  String get commonContinue => 'Continue';
}
