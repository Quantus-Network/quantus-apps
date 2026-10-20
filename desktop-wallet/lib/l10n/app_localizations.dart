import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Quantus Wallet'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get commonLoadMore;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @commonQtcAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} QTC'**
  String commonQtcAmount(String amount);

  /// No description provided for @commonApproximately.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount}'**
  String commonApproximately(String amount);

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get navSend;

  /// No description provided for @navReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get navReceive;

  /// No description provided for @navSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get navSwap;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add cold wallet account…'**
  String get navAddAccount;

  /// No description provided for @navDiscreetOn.
  ///
  /// In en, this message translates to:
  /// **'Discreet mode on'**
  String get navDiscreetOn;

  /// No description provided for @navDiscreetOff.
  ///
  /// In en, this message translates to:
  /// **'Discreet mode off'**
  String get navDiscreetOff;

  /// No description provided for @navShortcut.
  ///
  /// In en, this message translates to:
  /// **'{shortcut}'**
  String navShortcut(String shortcut);

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your cold wallet'**
  String get onboardingTitle;

  /// No description provided for @onboardingBody.
  ///
  /// In en, this message translates to:
  /// **'This wallet never holds a key. It watches an account whose keys live on your cold wallet phone, and every transaction is signed there.'**
  String get onboardingBody;

  /// No description provided for @onboardingStep1.
  ///
  /// In en, this message translates to:
  /// **'Open the cold wallet app on your phone'**
  String get onboardingStep1;

  /// No description provided for @onboardingStep2.
  ///
  /// In en, this message translates to:
  /// **'Show the account\'s address QR code'**
  String get onboardingStep2;

  /// No description provided for @onboardingStep3.
  ///
  /// In en, this message translates to:
  /// **'Hold it up to this camera'**
  String get onboardingStep3;

  /// No description provided for @onboardingScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the cold wallet'**
  String get onboardingScanHint;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT NAME'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingNameDefault.
  ///
  /// In en, this message translates to:
  /// **'Cold Wallet'**
  String get onboardingNameDefault;

  /// No description provided for @onboardingCompareBanner.
  ///
  /// In en, this message translates to:
  /// **'Compare this checkphrase with the one your cold wallet shows before continuing.'**
  String get onboardingCompareBanner;

  /// No description provided for @onboardingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get onboardingAdd;

  /// No description provided for @onboardingScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get onboardingScanAgain;

  /// No description provided for @onboardingDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This account is already in your wallet.'**
  String get onboardingDuplicate;

  /// No description provided for @onboardingInvalidAddress.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a Quantus address.'**
  String get onboardingInvalidAddress;

  /// No description provided for @onboardingSimulated.
  ///
  /// In en, this message translates to:
  /// **'Use the simulated cold wallet'**
  String get onboardingSimulated;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'TOTAL BALANCE'**
  String get dashboardTotalBalance;

  /// No description provided for @dashboardBalanceCard.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get dashboardBalanceCard;

  /// No description provided for @dashboardRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get dashboardRecent;

  /// No description provided for @dashboardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is ready'**
  String get dashboardEmptyTitle;

  /// No description provided for @dashboardEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Receive QTC to this account or swap another asset into it. Everything you send is signed on your cold wallet.'**
  String get dashboardEmptyBody;

  /// No description provided for @dashboardChartApproximate.
  ///
  /// In en, this message translates to:
  /// **'Reconstructed from indexed history; fees on reversible transfers are not included.'**
  String get dashboardChartApproximate;

  /// No description provided for @dashboardNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get dashboardNoActivity;

  /// No description provided for @chartRangeWeek.
  ///
  /// In en, this message translates to:
  /// **'1W'**
  String get chartRangeWeek;

  /// No description provided for @chartRangeMonth.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get chartRangeMonth;

  /// No description provided for @chartRangeQuarter.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get chartRangeQuarter;

  /// No description provided for @chartRangeYear.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get chartRangeYear;

  /// No description provided for @chartRangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chartRangeAll;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get accountPending;

  /// No description provided for @accountToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get accountToday;

  /// No description provided for @accountYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get accountYesterday;

  /// No description provided for @accountSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get accountSent;

  /// No description provided for @accountReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get accountReceived;

  /// No description provided for @accountSelfTransfer.
  ///
  /// In en, this message translates to:
  /// **'Self transfer'**
  String get accountSelfTransfer;

  /// No description provided for @accountMiningReward.
  ///
  /// In en, this message translates to:
  /// **'Mining reward'**
  String get accountMiningReward;

  /// No description provided for @accountReversibleScheduled.
  ///
  /// In en, this message translates to:
  /// **'Reversible transfer scheduled'**
  String get accountReversibleScheduled;

  /// No description provided for @accountReversibleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Reversible transfer cancelled'**
  String get accountReversibleCancelled;

  /// No description provided for @accountNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get accountNoTransactions;

  /// No description provided for @accountHistoryError.
  ///
  /// In en, this message translates to:
  /// **'Could not load history.'**
  String get accountHistoryError;

  /// No description provided for @accountCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get accountCopyAddress;

  /// No description provided for @accountCopyHash.
  ///
  /// In en, this message translates to:
  /// **'Copy transaction hash'**
  String get accountCopyHash;

  /// No description provided for @accountOpenExplorer.
  ///
  /// In en, this message translates to:
  /// **'View in explorer'**
  String get accountOpenExplorer;

  /// No description provided for @txDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get txDetailTitle;

  /// No description provided for @txDetailAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get txDetailAmount;

  /// No description provided for @txDetailFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get txDetailFee;

  /// No description provided for @txDetailFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get txDetailFrom;

  /// No description provided for @txDetailTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get txDetailTo;

  /// No description provided for @txDetailDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get txDetailDate;

  /// No description provided for @txDetailHash.
  ///
  /// In en, this message translates to:
  /// **'Transaction hash'**
  String get txDetailHash;

  /// No description provided for @txDetailBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get txDetailBlock;

  /// No description provided for @txDetailStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get txDetailStatusPending;

  /// No description provided for @txDetailStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get txDetailStatusConfirmed;

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTitle;

  /// No description provided for @sendRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'RECIPIENT'**
  String get sendRecipientLabel;

  /// No description provided for @sendRecipientHint.
  ///
  /// In en, this message translates to:
  /// **'Quantus address'**
  String get sendRecipientHint;

  /// No description provided for @sendRecipientInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid Quantus address.'**
  String get sendRecipientInvalid;

  /// No description provided for @sendRecipientSelf.
  ///
  /// In en, this message translates to:
  /// **'This is the account you are sending from.'**
  String get sendRecipientSelf;

  /// No description provided for @sendAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT'**
  String get sendAmountLabel;

  /// No description provided for @sendAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get sendAmountHint;

  /// No description provided for @sendMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get sendMax;

  /// No description provided for @sendUnitQtc.
  ///
  /// In en, this message translates to:
  /// **'QTC'**
  String get sendUnitQtc;

  /// No description provided for @sendFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get sendFee;

  /// No description provided for @sendTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get sendTotal;

  /// No description provided for @sendInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough balance for this amount and fee.'**
  String get sendInsufficient;

  /// No description provided for @sendFeeError.
  ///
  /// In en, this message translates to:
  /// **'Could not estimate the fee.'**
  String get sendFeeError;

  /// No description provided for @sendReview.
  ///
  /// In en, this message translates to:
  /// **'Review & sign'**
  String get sendReview;

  /// No description provided for @sendNoPrice.
  ///
  /// In en, this message translates to:
  /// **'Fiat conversion is unavailable until a QTC price is known.'**
  String get sendNoPrice;

  /// No description provided for @signTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign with your cold wallet'**
  String get signTitle;

  /// No description provided for @signStepShow.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get signStepShow;

  /// No description provided for @signStepVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify on device'**
  String get signStepVerify;

  /// No description provided for @signStepScan.
  ///
  /// In en, this message translates to:
  /// **'Scan signature'**
  String get signStepScan;

  /// No description provided for @signYouAreSigning.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE SIGNING'**
  String get signYouAreSigning;

  /// No description provided for @signAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get signAmount;

  /// No description provided for @signTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get signTo;

  /// No description provided for @signShowInstruction.
  ///
  /// In en, this message translates to:
  /// **'Open the cold wallet app and scan this code.'**
  String get signShowInstruction;

  /// No description provided for @signValidFor.
  ///
  /// In en, this message translates to:
  /// **'Refreshes automatically · valid for {time}'**
  String signValidFor(String time);

  /// No description provided for @signRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Code refreshed. Scan it again on your phone.'**
  String get signRefreshed;

  /// No description provided for @signPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the transaction…'**
  String get signPreparing;

  /// No description provided for @signPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the transaction. Check your connection and try again.'**
  String get signPrepareFailed;

  /// No description provided for @signScannedContinue.
  ///
  /// In en, this message translates to:
  /// **'I scanned it, continue'**
  String get signScannedContinue;

  /// No description provided for @signPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get signPause;

  /// No description provided for @signResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get signResume;

  /// No description provided for @signVerifyInstruction.
  ///
  /// In en, this message translates to:
  /// **'Your cold wallet shows the transaction it is about to sign. Approve it there only if every detail matches what you see here.'**
  String get signVerifyInstruction;

  /// No description provided for @signVerifyWarning.
  ///
  /// In en, this message translates to:
  /// **'If the amount or the recipient differ, reject the transaction on your cold wallet. Do not approve it.'**
  String get signVerifyWarning;

  /// No description provided for @signMatches.
  ///
  /// In en, this message translates to:
  /// **'It matches, continue'**
  String get signMatches;

  /// No description provided for @signMismatch.
  ///
  /// In en, this message translates to:
  /// **'It doesn\'t match'**
  String get signMismatch;

  /// No description provided for @signRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject it on your cold wallet'**
  String get signRejectedTitle;

  /// No description provided for @signRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'The transaction shown on the device is not the one you prepared here. Reject it on the cold wallet and do not scan its signature.'**
  String get signRejectedBody;

  /// No description provided for @signRejectedDone.
  ///
  /// In en, this message translates to:
  /// **'I rejected it on the cold wallet'**
  String get signRejectedDone;

  /// No description provided for @signScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Hold the cold wallet\'s signature QR code up to the camera.'**
  String get signScanInstruction;

  /// No description provided for @signScanLabel.
  ///
  /// In en, this message translates to:
  /// **'RECEIVING SIGNATURE'**
  String get signScanLabel;

  /// No description provided for @signScanProgress.
  ///
  /// In en, this message translates to:
  /// **'{scanned} / {total}'**
  String signScanProgress(int scanned, int total);

  /// No description provided for @signScanScanning.
  ///
  /// In en, this message translates to:
  /// **'{count} frames'**
  String signScanScanning(int count);

  /// No description provided for @signScanStall.
  ///
  /// In en, this message translates to:
  /// **'Not picking up new frames. Move closer, raise the phone\'s brightness and avoid glare.'**
  String get signScanStall;

  /// No description provided for @signScanMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing frames: {list}'**
  String signScanMissing(String list);

  /// No description provided for @signScanMissingMore.
  ///
  /// In en, this message translates to:
  /// **'{list} and {more} more'**
  String signScanMissingMore(String list, int more);

  /// No description provided for @signScanError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the signature. Scanning again…'**
  String get signScanError;

  /// No description provided for @signScanComplete.
  ///
  /// In en, this message translates to:
  /// **'Signature received'**
  String get signScanComplete;

  /// No description provided for @signRejectedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'I rejected it on the device'**
  String get signRejectedOnDevice;

  /// No description provided for @signSimulate.
  ///
  /// In en, this message translates to:
  /// **'Simulate the cold wallet\'s signature'**
  String get signSimulate;

  /// No description provided for @signSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting transaction…'**
  String get signSubmitting;

  /// No description provided for @signExpired.
  ///
  /// In en, this message translates to:
  /// **'The transaction expired before it could be submitted. Show the QR code again and sign it afresh.'**
  String get signExpired;

  /// No description provided for @signBackToQr.
  ///
  /// In en, this message translates to:
  /// **'Back to the QR code'**
  String get signBackToQr;

  /// No description provided for @signWrongSigner.
  ///
  /// In en, this message translates to:
  /// **'The signature came from a different account than the one you are sending from. Check which account is selected on your cold wallet.'**
  String get signWrongSigner;

  /// No description provided for @signInvalid.
  ///
  /// In en, this message translates to:
  /// **'The signature does not verify for this transaction. Sign it again on your cold wallet.'**
  String get signInvalid;

  /// No description provided for @signSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'The network rejected the transaction: {error}'**
  String signSubmitFailed(String error);

  /// No description provided for @signDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop signing?'**
  String get signDiscardTitle;

  /// No description provided for @signDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The frames scanned so far will be discarded.'**
  String get signDiscardBody;

  /// No description provided for @signDiscardAction.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get signDiscardAction;

  /// No description provided for @signSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction submitted'**
  String get signSuccessTitle;

  /// No description provided for @signSuccessPending.
  ///
  /// In en, this message translates to:
  /// **'Usually confirms within a minute'**
  String get signSuccessPending;

  /// No description provided for @receiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

  /// No description provided for @receiveYourAddress.
  ///
  /// In en, this message translates to:
  /// **'YOUR ADDRESS'**
  String get receiveYourAddress;

  /// No description provided for @receiveCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get receiveCopy;

  /// No description provided for @receiveCompareBanner.
  ///
  /// In en, this message translates to:
  /// **'Before sharing, compare the checkphrase with the one your cold wallet shows for this account.'**
  String get receiveCompareBanner;

  /// No description provided for @swapTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swapTitle;

  /// No description provided for @swapIntro.
  ///
  /// In en, this message translates to:
  /// **'Swap QTC for another asset. The deposit is signed on your cold wallet like any other transaction.'**
  String get swapIntro;

  /// No description provided for @swapPayLabel.
  ///
  /// In en, this message translates to:
  /// **'YOU PAY'**
  String get swapPayLabel;

  /// No description provided for @swapReceiveLabel.
  ///
  /// In en, this message translates to:
  /// **'YOU RECEIVE'**
  String get swapReceiveLabel;

  /// No description provided for @swapToLabel.
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get swapToLabel;

  /// No description provided for @swapPickToken.
  ///
  /// In en, this message translates to:
  /// **'Choose a token'**
  String get swapPickToken;

  /// No description provided for @swapRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'RECIPIENT ON {network}'**
  String swapRecipientLabel(String network);

  /// No description provided for @swapRecipientHint.
  ///
  /// In en, this message translates to:
  /// **'{network} address'**
  String swapRecipientHint(String network);

  /// No description provided for @swapRecipientNotice.
  ///
  /// In en, this message translates to:
  /// **'Your {symbol} will arrive at this address. Double-check it, swaps cannot be reversed.'**
  String swapRecipientNotice(String symbol);

  /// No description provided for @swapSaveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save this address for future swaps'**
  String get swapSaveAddress;

  /// No description provided for @swapSlippage.
  ///
  /// In en, this message translates to:
  /// **'SLIPPAGE TOLERANCE'**
  String get swapSlippage;

  /// No description provided for @swapSlippageBody.
  ///
  /// In en, this message translates to:
  /// **'If the price moves further than this before the swap fills, it is refunded instead.'**
  String get swapSlippageBody;

  /// No description provided for @swapSlippagePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String swapSlippagePercent(String percent);

  /// No description provided for @swapEstimate.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount} at listed prices'**
  String swapEstimate(String amount);

  /// No description provided for @swapGetQuote.
  ///
  /// In en, this message translates to:
  /// **'Get a quote'**
  String get swapGetQuote;

  /// No description provided for @swapQuoteError.
  ///
  /// In en, this message translates to:
  /// **'Quote failed: {message}'**
  String swapQuoteError(String message);

  /// No description provided for @swapTokensError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the token list: {message}'**
  String swapTokensError(String message);

  /// No description provided for @swapNoQuantusListing.
  ///
  /// In en, this message translates to:
  /// **'QTC is not listed for swapping right now.'**
  String get swapNoQuantusListing;

  /// No description provided for @swapReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review swap'**
  String get swapReviewTitle;

  /// No description provided for @swapRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get swapRate;

  /// No description provided for @swapRateValue.
  ///
  /// In en, this message translates to:
  /// **'1 {from} = {rate} {to}'**
  String swapRateValue(String from, String rate, String to);

  /// No description provided for @swapRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get swapRecipient;

  /// No description provided for @swapRefundAddress.
  ///
  /// In en, this message translates to:
  /// **'Refund address'**
  String get swapRefundAddress;

  /// No description provided for @swapNetworkFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get swapNetworkFee;

  /// No description provided for @swapFeeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get swapFeeUnavailable;

  /// No description provided for @swapSlippageAllowance.
  ///
  /// In en, this message translates to:
  /// **'Slippage allowance'**
  String get swapSlippageAllowance;

  /// No description provided for @swapSlippageAllowanceValue.
  ///
  /// In en, this message translates to:
  /// **'{amount} ({percent}%)'**
  String swapSlippageAllowanceValue(String amount, String percent);

  /// No description provided for @swapGuaranteedMinimum.
  ///
  /// In en, this message translates to:
  /// **'Guaranteed minimum'**
  String get swapGuaranteedMinimum;

  /// No description provided for @swapUnusedRefunded.
  ///
  /// In en, this message translates to:
  /// **'The payment includes the slippage allowance. Whatever the swap does not use is refunded.'**
  String get swapUnusedRefunded;

  /// No description provided for @swapInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough QTC for this amount plus the network fee.'**
  String get swapInsufficient;

  /// No description provided for @swapPriceMoved.
  ///
  /// In en, this message translates to:
  /// **'The price moved. Check the new amounts and confirm again.'**
  String get swapPriceMoved;

  /// No description provided for @swapConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm and sign'**
  String get swapConfirm;

  /// No description provided for @swapCreateError.
  ///
  /// In en, this message translates to:
  /// **'Could not reserve a deposit address: {message}'**
  String swapCreateError(String message);

  /// No description provided for @swapQuoteExpiredBeforeDeposit.
  ///
  /// In en, this message translates to:
  /// **'The quote expired before the deposit was broadcast. Start over to get a fresh one.'**
  String get swapQuoteExpiredBeforeDeposit;

  /// No description provided for @swapInProgress.
  ///
  /// In en, this message translates to:
  /// **'Swap in progress'**
  String get swapInProgress;

  /// No description provided for @swapStepSent.
  ///
  /// In en, this message translates to:
  /// **'QTC sent'**
  String get swapStepSent;

  /// No description provided for @swapStepConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming on Quantus'**
  String get swapStepConfirming;

  /// No description provided for @swapStepSwapping.
  ///
  /// In en, this message translates to:
  /// **'Swapping'**
  String get swapStepSwapping;

  /// No description provided for @swapStepSending.
  ///
  /// In en, this message translates to:
  /// **'Sending {symbol} to {recipient}'**
  String swapStepSending(String symbol, String recipient);

  /// No description provided for @swapProgressFooter.
  ///
  /// In en, this message translates to:
  /// **'Usually a few minutes. The swap finishes even if you leave this screen.'**
  String get swapProgressFooter;

  /// No description provided for @swapDepositTransaction.
  ///
  /// In en, this message translates to:
  /// **'Deposit transaction'**
  String get swapDepositTransaction;

  /// No description provided for @swapComplete.
  ///
  /// In en, this message translates to:
  /// **'Swap complete'**
  String get swapComplete;

  /// No description provided for @swapReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get swapReceived;

  /// No description provided for @swapFailed.
  ///
  /// In en, this message translates to:
  /// **'Swap failed'**
  String get swapFailed;

  /// No description provided for @swapRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get swapRefunded;

  /// No description provided for @swapRefundedBody.
  ///
  /// In en, this message translates to:
  /// **'The swap could not be completed, so {amount} returns to {account}, minus the network fee. The {symbol} was never sent.'**
  String swapRefundedBody(String amount, String account, String symbol);

  /// No description provided for @swapRefundReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String swapRefundReason(String reason);

  /// No description provided for @swapDepositIncompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit too small'**
  String get swapDepositIncompleteTitle;

  /// No description provided for @swapDepositIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Less than the quoted amount arrived. It will be refunded after the deadline.'**
  String get swapDepositIncompleteBody;

  /// No description provided for @swapExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Quote expired'**
  String get swapExpiredTitle;

  /// No description provided for @swapExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'No deposit arrived before the deadline. Start over to get a new quote.'**
  String get swapExpiredBody;

  /// No description provided for @swapFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The swap did not complete. Contact support and quote this deposit address: {address}'**
  String swapFailedBody(String address);

  /// No description provided for @swapStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start a new swap'**
  String get swapStartNew;

  /// No description provided for @swapTokenPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a token'**
  String get swapTokenPickerTitle;

  /// No description provided for @swapTokenSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search token or chain'**
  String get swapTokenSearchHint;

  /// No description provided for @swapTokenNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No tokens match your search'**
  String get swapTokenNoMatch;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// No description provided for @settingsFiat.
  ///
  /// In en, this message translates to:
  /// **'Fiat currency'**
  String get settingsFiat;

  /// No description provided for @settingsDiscreet.
  ///
  /// In en, this message translates to:
  /// **'Discreet mode'**
  String get settingsDiscreet;

  /// No description provided for @settingsDiscreetBody.
  ///
  /// In en, this message translates to:
  /// **'Hide balances and amounts until you hover over them.'**
  String get settingsDiscreetBody;

  /// No description provided for @settingsQr.
  ///
  /// In en, this message translates to:
  /// **'Cold wallet QR codes'**
  String get settingsQr;

  /// No description provided for @settingsQrFps.
  ///
  /// In en, this message translates to:
  /// **'Frames per second'**
  String get settingsQrFps;

  /// No description provided for @settingsQrBytes.
  ///
  /// In en, this message translates to:
  /// **'Bytes per frame'**
  String get settingsQrBytes;

  /// No description provided for @settingsQrBody.
  ///
  /// In en, this message translates to:
  /// **'More bytes per frame means fewer frames but a denser code; a higher rate finishes sooner but phone cameras miss frames above about 12 per second.'**
  String get settingsQrBody;

  /// No description provided for @settingsCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get settingsCamera;

  /// No description provided for @settingsCameraNone.
  ///
  /// In en, this message translates to:
  /// **'No camera found.'**
  String get settingsCameraNone;

  /// No description provided for @settingsCameraTest.
  ///
  /// In en, this message translates to:
  /// **'Test camera'**
  String get settingsCameraTest;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsNetwork;

  /// No description provided for @settingsNetworkMainnet.
  ///
  /// In en, this message translates to:
  /// **'Mainnet'**
  String get settingsNetworkMainnet;

  /// No description provided for @settingsNetworkTestnet.
  ///
  /// In en, this message translates to:
  /// **'Testnet'**
  String get settingsNetworkTestnet;

  /// No description provided for @settingsAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get settingsAccounts;

  /// No description provided for @settingsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get settingsRename;

  /// No description provided for @settingsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get settingsRemove;

  /// No description provided for @settingsRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String settingsRemoveTitle(String name);

  /// No description provided for @settingsRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The account stays on your cold wallet and on the chain. You can scan it in again at any time.'**
  String get settingsRemoveBody;

  /// No description provided for @settingsRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemoveAction;

  /// No description provided for @settingsRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename account'**
  String get settingsRenameTitle;

  /// No description provided for @cameraPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get cameraPermissionTitle;

  /// No description provided for @cameraPermissionMac.
  ///
  /// In en, this message translates to:
  /// **'Allow Quantus Wallet to use the camera in System Settings → Privacy & Security → Camera, then try again.'**
  String get cameraPermissionMac;

  /// No description provided for @cameraPermissionWindows.
  ///
  /// In en, this message translates to:
  /// **'Allow desktop apps to use the camera in Settings → Privacy & security → Camera, then try again.'**
  String get cameraPermissionWindows;

  /// No description provided for @cameraPermissionLinux.
  ///
  /// In en, this message translates to:
  /// **'Make sure your user can access the camera device and the GStreamer plugins are installed, then try again.'**
  String get cameraPermissionLinux;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be started: {error}'**
  String cameraError(String error);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
