// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Quantus Wallet';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonLoadMore => 'Load more';

  @override
  String get commonViewAll => 'View all';

  @override
  String commonQtcAmount(String amount) {
    return '$amount QTC';
  }

  @override
  String commonApproximately(String amount) {
    return '≈ $amount';
  }

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navAccount => 'Account';

  @override
  String get navSend => 'Send';

  @override
  String get navReceive => 'Receive';

  @override
  String get navSwap => 'Swap';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAddAccount => 'Add cold wallet account…';

  @override
  String get navDiscreetOn => 'Discreet mode on';

  @override
  String get navDiscreetOff => 'Discreet mode off';

  @override
  String navShortcut(String shortcut) {
    return '$shortcut';
  }

  @override
  String get onboardingTitle => 'Connect your cold wallet';

  @override
  String get onboardingBody =>
      'This wallet never holds a key. It watches an account whose keys live on your cold wallet phone, and every transaction is signed there.';

  @override
  String get onboardingStep1 => 'Open the cold wallet app on your phone';

  @override
  String get onboardingStep2 => 'Show the account\'s address QR code';

  @override
  String get onboardingStep3 => 'Hold it up to this camera';

  @override
  String get onboardingScanHint => 'Point the camera at the cold wallet';

  @override
  String get onboardingNameLabel => 'ACCOUNT NAME';

  @override
  String get onboardingNameDefault => 'Cold Wallet';

  @override
  String get onboardingCompareBanner =>
      'Compare this checkphrase with the one your cold wallet shows before continuing.';

  @override
  String get onboardingAdd => 'Add account';

  @override
  String get onboardingScanAgain => 'Scan again';

  @override
  String get onboardingDuplicate => 'This account is already in your wallet.';

  @override
  String get onboardingInvalidAddress => 'That QR code is not a Quantus address.';

  @override
  String get onboardingSimulated => 'Use the simulated cold wallet';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardTotalBalance => 'TOTAL BALANCE';

  @override
  String get dashboardBalanceCard => 'Balance';

  @override
  String get dashboardRecent => 'Recent transactions';

  @override
  String get dashboardEmptyTitle => 'Your wallet is ready';

  @override
  String get dashboardEmptyBody =>
      'Receive QTC to this account or swap another asset into it. Everything you send is signed on your cold wallet.';

  @override
  String get dashboardChartApproximate =>
      'Reconstructed from indexed history; fees on reversible transfers are not included.';

  @override
  String get dashboardNoActivity => 'No activity yet';

  @override
  String get chartRangeWeek => '1W';

  @override
  String get chartRangeMonth => '1M';

  @override
  String get chartRangeQuarter => '3M';

  @override
  String get chartRangeYear => '1Y';

  @override
  String get chartRangeAll => 'All';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountPending => 'Pending';

  @override
  String get accountToday => 'Today';

  @override
  String get accountYesterday => 'Yesterday';

  @override
  String get accountSent => 'Sent';

  @override
  String get accountReceived => 'Received';

  @override
  String get accountSelfTransfer => 'Self transfer';

  @override
  String get accountMiningReward => 'Mining reward';

  @override
  String get accountReversibleScheduled => 'Reversible transfer scheduled';

  @override
  String get accountReversibleCancelled => 'Reversible transfer cancelled';

  @override
  String get accountNoTransactions => 'No transactions yet';

  @override
  String get accountHistoryError => 'Could not load history.';

  @override
  String get accountCopyAddress => 'Copy address';

  @override
  String get accountCopyHash => 'Copy transaction hash';

  @override
  String get accountOpenExplorer => 'View in explorer';

  @override
  String get txDetailTitle => 'Transaction';

  @override
  String get txDetailAmount => 'Amount';

  @override
  String get txDetailFee => 'Network fee';

  @override
  String get txDetailFrom => 'From';

  @override
  String get txDetailTo => 'To';

  @override
  String get txDetailDate => 'Date';

  @override
  String get txDetailHash => 'Transaction hash';

  @override
  String get txDetailBlock => 'Block';

  @override
  String get txDetailStatusPending => 'Pending';

  @override
  String get txDetailStatusConfirmed => 'Confirmed';

  @override
  String get sendTitle => 'Send';

  @override
  String get sendRecipientLabel => 'RECIPIENT';

  @override
  String get sendRecipientHint => 'Quantus address';

  @override
  String get sendRecipientInvalid => 'This is not a valid Quantus address.';

  @override
  String get sendRecipientSelf => 'This is the account you are sending from.';

  @override
  String get sendAmountLabel => 'AMOUNT';

  @override
  String get sendAmountHint => '0.00';

  @override
  String get sendMax => 'Max';

  @override
  String get sendUnitQtc => 'QTC';

  @override
  String get sendFee => 'Network fee';

  @override
  String get sendTotal => 'Total';

  @override
  String get sendInsufficient => 'Not enough balance for this amount and fee.';

  @override
  String get sendFeeError => 'Could not estimate the fee.';

  @override
  String get sendReview => 'Review & sign';

  @override
  String get sendNoPrice => 'Fiat conversion is unavailable until a QTC price is known.';

  @override
  String get signTitle => 'Sign with your cold wallet';

  @override
  String get signStepShow => 'Show QR';

  @override
  String get signStepVerify => 'Verify on device';

  @override
  String get signStepScan => 'Scan signature';

  @override
  String get signYouAreSigning => 'YOU ARE SIGNING';

  @override
  String get signAmount => 'Amount';

  @override
  String get signTo => 'To';

  @override
  String get signShowInstruction => 'Open the cold wallet app and scan this code.';

  @override
  String signValidFor(String time) {
    return 'Refreshes automatically · valid for $time';
  }

  @override
  String get signRefreshed => 'Code refreshed. Scan it again on your phone.';

  @override
  String get signPreparing => 'Preparing the transaction…';

  @override
  String get signPrepareFailed => 'Could not prepare the transaction. Check your connection and try again.';

  @override
  String get signScannedContinue => 'I scanned it, continue';

  @override
  String get signPause => 'Pause';

  @override
  String get signResume => 'Resume';

  @override
  String get signVerifyInstruction =>
      'Your cold wallet shows the transaction it is about to sign. Approve it there only if every detail matches what you see here.';

  @override
  String get signVerifyWarning =>
      'If the amount or the recipient differ, reject the transaction on your cold wallet. Do not approve it.';

  @override
  String get signMatches => 'It matches, continue';

  @override
  String get signMismatch => 'It doesn\'t match';

  @override
  String get signRejectedTitle => 'Reject it on your cold wallet';

  @override
  String get signRejectedBody =>
      'The transaction shown on the device is not the one you prepared here. Reject it on the cold wallet and do not scan its signature.';

  @override
  String get signRejectedDone => 'I rejected it on the cold wallet';

  @override
  String get signScanInstruction => 'Hold the cold wallet\'s signature QR code up to the camera.';

  @override
  String get signScanLabel => 'RECEIVING SIGNATURE';

  @override
  String signScanProgress(int scanned, int total) {
    return '$scanned / $total';
  }

  @override
  String signScanScanning(int count) {
    return '$count frames';
  }

  @override
  String get signScanStall => 'Not picking up new frames. Move closer, raise the phone\'s brightness and avoid glare.';

  @override
  String signScanMissing(String list) {
    return 'Missing frames: $list';
  }

  @override
  String signScanMissingMore(String list, int more) {
    return '$list and $more more';
  }

  @override
  String get signScanError => 'Could not read the signature. Scanning again…';

  @override
  String get signScanComplete => 'Signature received';

  @override
  String get signRejectedOnDevice => 'I rejected it on the device';

  @override
  String get signSimulate => 'Simulate the cold wallet\'s signature';

  @override
  String get signSubmitting => 'Submitting transaction…';

  @override
  String get signExpired =>
      'The transaction expired before it could be submitted. Show the QR code again and sign it afresh.';

  @override
  String get signBackToQr => 'Back to the QR code';

  @override
  String get signWrongSigner =>
      'The signature came from a different account than the one you are sending from. Check which account is selected on your cold wallet.';

  @override
  String get signInvalid => 'The signature does not verify for this transaction. Sign it again on your cold wallet.';

  @override
  String signSubmitFailed(String error) {
    return 'The network rejected the transaction: $error';
  }

  @override
  String get signDiscardTitle => 'Stop signing?';

  @override
  String get signDiscardBody => 'The frames scanned so far will be discarded.';

  @override
  String get signDiscardAction => 'Stop';

  @override
  String get signSuccessTitle => 'Transaction submitted';

  @override
  String get signSuccessPending => 'Usually confirms within a minute';

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receiveYourAddress => 'YOUR ADDRESS';

  @override
  String get receiveCopy => 'Copy address';

  @override
  String get receiveCompareBanner =>
      'Before sharing, compare the checkphrase with the one your cold wallet shows for this account.';

  @override
  String get swapTitle => 'Swap';

  @override
  String get swapIntro =>
      'Swap QTC for another asset. The deposit is signed on your cold wallet like any other transaction.';

  @override
  String get swapPayLabel => 'YOU PAY';

  @override
  String get swapReceiveLabel => 'YOU RECEIVE';

  @override
  String get swapToLabel => 'TO';

  @override
  String get swapPickToken => 'Choose a token';

  @override
  String swapRecipientLabel(String network) {
    return 'RECIPIENT ON $network';
  }

  @override
  String swapRecipientHint(String network) {
    return '$network address';
  }

  @override
  String swapRecipientNotice(String symbol) {
    return 'Your $symbol will arrive at this address. Double-check it, swaps cannot be reversed.';
  }

  @override
  String get swapSaveAddress => 'Save this address for future swaps';

  @override
  String get swapSlippage => 'SLIPPAGE TOLERANCE';

  @override
  String get swapSlippageBody => 'If the price moves further than this before the swap fills, it is refunded instead.';

  @override
  String swapSlippagePercent(String percent) {
    return '$percent%';
  }

  @override
  String swapEstimate(String amount) {
    return '≈ $amount at listed prices';
  }

  @override
  String get swapGetQuote => 'Get a quote';

  @override
  String swapQuoteError(String message) {
    return 'Quote failed: $message';
  }

  @override
  String swapTokensError(String message) {
    return 'Could not load the token list: $message';
  }

  @override
  String get swapNoQuantusListing => 'QTC is not listed for swapping right now.';

  @override
  String get swapReviewTitle => 'Review swap';

  @override
  String get swapRate => 'Rate';

  @override
  String swapRateValue(String from, String rate, String to) {
    return '1 $from = $rate $to';
  }

  @override
  String get swapRecipient => 'Recipient';

  @override
  String get swapRefundAddress => 'Refund address';

  @override
  String get swapNetworkFee => 'Network fee';

  @override
  String get swapFeeUnavailable => 'Unavailable';

  @override
  String get swapSlippageAllowance => 'Slippage allowance';

  @override
  String swapSlippageAllowanceValue(String amount, String percent) {
    return '$amount ($percent%)';
  }

  @override
  String get swapGuaranteedMinimum => 'Guaranteed minimum';

  @override
  String get swapUnusedRefunded =>
      'The payment includes the slippage allowance. Whatever the swap does not use is refunded.';

  @override
  String get swapInsufficient => 'Not enough QTC for this amount plus the network fee.';

  @override
  String get swapPriceMoved => 'The price moved. Check the new amounts and confirm again.';

  @override
  String get swapConfirm => 'Confirm and sign';

  @override
  String swapCreateError(String message) {
    return 'Could not reserve a deposit address: $message';
  }

  @override
  String get swapQuoteExpiredBeforeDeposit =>
      'The quote expired before the deposit was broadcast. Start over to get a fresh one.';

  @override
  String get swapInProgress => 'Swap in progress';

  @override
  String get swapStepSent => 'QTC sent';

  @override
  String get swapStepConfirming => 'Confirming on Quantus';

  @override
  String get swapStepSwapping => 'Swapping';

  @override
  String swapStepSending(String symbol, String recipient) {
    return 'Sending $symbol to $recipient';
  }

  @override
  String get swapProgressFooter => 'Usually a few minutes. The swap finishes even if you leave this screen.';

  @override
  String get swapDepositTransaction => 'Deposit transaction';

  @override
  String get swapComplete => 'Swap complete';

  @override
  String get swapReceived => 'Received';

  @override
  String get swapFailed => 'Swap failed';

  @override
  String get swapRefunded => 'Refunded';

  @override
  String swapRefundedBody(String amount, String account, String symbol) {
    return 'The swap could not be completed, so $amount returns to $account, minus the network fee. The $symbol was never sent.';
  }

  @override
  String swapRefundReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get swapDepositIncompleteTitle => 'Deposit too small';

  @override
  String get swapDepositIncompleteBody =>
      'Less than the quoted amount arrived. It will be refunded after the deadline.';

  @override
  String get swapExpiredTitle => 'Quote expired';

  @override
  String get swapExpiredBody => 'No deposit arrived before the deadline. Start over to get a new quote.';

  @override
  String swapFailedBody(String address) {
    return 'The swap did not complete. Contact support and quote this deposit address: $address';
  }

  @override
  String get swapStartNew => 'Start a new swap';

  @override
  String get swapTokenPickerTitle => 'Choose a token';

  @override
  String get swapTokenSearchHint => 'Search token or chain';

  @override
  String get swapTokenNoMatch => 'No tokens match your search';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsFiat => 'Fiat currency';

  @override
  String get settingsDiscreet => 'Discreet mode';

  @override
  String get settingsDiscreetBody => 'Hide balances and amounts until you hover over them.';

  @override
  String get settingsQr => 'Cold wallet QR codes';

  @override
  String get settingsQrFps => 'Frames per second';

  @override
  String get settingsQrBytes => 'Bytes per frame';

  @override
  String get settingsQrBody =>
      'More bytes per frame means fewer frames but a denser code; a higher rate finishes sooner but phone cameras miss frames above about 12 per second.';

  @override
  String get settingsCamera => 'Camera';

  @override
  String get settingsCameraNone => 'No camera found.';

  @override
  String get settingsCameraTest => 'Test camera';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsNetwork => 'Network';

  @override
  String get settingsNetworkMainnet => 'Mainnet';

  @override
  String get settingsNetworkTestnet => 'Testnet';

  @override
  String get settingsAccounts => 'Accounts';

  @override
  String get settingsRename => 'Rename';

  @override
  String get settingsRemove => 'Remove account';

  @override
  String settingsRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get settingsRemoveBody =>
      'The account stays on your cold wallet and on the chain. You can scan it in again at any time.';

  @override
  String get settingsRemoveAction => 'Remove';

  @override
  String get settingsRenameTitle => 'Rename account';

  @override
  String get cameraPermissionTitle => 'Camera access is off';

  @override
  String get cameraPermissionMac =>
      'Allow Quantus Wallet to use the camera in System Settings → Privacy & Security → Camera, then try again.';

  @override
  String get cameraPermissionWindows =>
      'Allow desktop apps to use the camera in Settings → Privacy & security → Camera, then try again.';

  @override
  String get cameraPermissionLinux =>
      'Make sure your user can access the camera device and the GStreamer plugins are installed, then try again.';

  @override
  String cameraError(String error) {
    return 'The camera could not be started: $error';
  }
}
