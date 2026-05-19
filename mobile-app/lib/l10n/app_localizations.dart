import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('id')];

  /// Title for the error dialog when the wallet is not found
  ///
  /// In en, this message translates to:
  /// **'Wallet Error'**
  String get walletInitErrorTitle;

  /// Message for the error dialog when the wallet is not found
  ///
  /// In en, this message translates to:
  /// **'Unable to find secret phrase. Please restore your wallet.'**
  String get walletInitErrorMessage;

  /// Label for the button on the error dialog when the wallet is not found
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get walletInitErrorButtonLabel;

  /// Text for the text on the lock screen when using device biometrics to unlock
  ///
  /// In en, this message translates to:
  /// **'Use device biometrics to unlock'**
  String get authUseDeviceBiometricsToUnlock;

  /// Text for the text on the lock screen when authenticating
  ///
  /// In en, this message translates to:
  /// **'Authenticating...'**
  String get authAuthenticating;

  /// Text for the button on the lock screen to unlock the wallet
  ///
  /// In en, this message translates to:
  /// **'Unlock Wallet'**
  String get authUnlockWallet;

  /// Text for displayed on the lock screen when authorization is required
  ///
  /// In en, this message translates to:
  /// **'Authorization \n Required'**
  String get authAuthorizationRequired;

  /// Tagline on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Quantum Secure Encrypted Money'**
  String get welcomeTagline;

  /// Button to start creating a new wallet on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Create New Wallet'**
  String get welcomeCreateNewWallet;

  /// Button to import an existing wallet on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Import Wallet'**
  String get welcomeImportWallet;

  /// App bar title for the create wallet flow
  ///
  /// In en, this message translates to:
  /// **'Create Wallet'**
  String get createWalletAppBarTitle;

  /// Headline on the recovery phrase caution screen during wallet creation
  ///
  /// In en, this message translates to:
  /// **'Keep your Recovery Phrase Secret'**
  String get createWalletCautionHeadline;

  /// First bullet on the recovery phrase caution screen
  ///
  /// In en, this message translates to:
  /// **'If you lose this device, your recovery phrase is the only way back'**
  String get createWalletCautionBullet1;

  /// Second bullet on the recovery phrase caution screen
  ///
  /// In en, this message translates to:
  /// **'Anyone who gets hold of it has complete control over your funds, permanently'**
  String get createWalletCautionBullet2;

  /// Third bullet on the recovery phrase caution screen
  ///
  /// In en, this message translates to:
  /// **'Write it down and keep it somewhere safe. Do not save it digitally'**
  String get createWalletCautionBullet3;

  /// Checkbox label on the recovery phrase caution screen
  ///
  /// In en, this message translates to:
  /// **'I understand that anyone with my recovery phrase can access my wallet. I will store it safely.'**
  String get createWalletCautionCheckboxLabel;

  /// Continue button on the recovery phrase caution screen
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get createWalletCautionContinue;

  /// Primary button on the new wallet recovery phrase screen
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get createWalletRecoveryPhraseNext;

  /// Error when mnemonic generation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to generate: {error}'**
  String createWalletRecoveryPhraseFailedGenerate(String error);

  /// Error when saving a new wallet fails
  ///
  /// In en, this message translates to:
  /// **'Error saving wallet: {error}'**
  String createWalletRecoveryPhraseSaveError(String error);

  /// Instructions above the recovery phrase word grid
  ///
  /// In en, this message translates to:
  /// **'Write these words down in order and keep them somewhere only you can access. Do not screenshot or copy to a notes app.'**
  String get recoveryPhraseBodyInstructions;

  /// Copy button on the recovery phrase screen
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get recoveryPhraseBodyCopy;

  /// Toast when recovery phrase is copied
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase copied to clipboard'**
  String get recoveryPhraseBodyCopiedMessage;

  /// Title when a new account is created
  ///
  /// In en, this message translates to:
  /// **'Account Created'**
  String get accountReadyAccountCreated;

  /// Title when a new wallet is created
  ///
  /// In en, this message translates to:
  /// **'Wallet Created'**
  String get accountReadyWalletCreated;

  /// Title when a wallet is imported
  ///
  /// In en, this message translates to:
  /// **'Wallet Imported'**
  String get accountReadyWalletImported;

  /// Done button on the account ready screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get accountReadyDone;

  /// App bar title on the import wallet screen
  ///
  /// In en, this message translates to:
  /// **'Import Wallet'**
  String get importWalletAppBarTitle;

  /// Description on the import wallet screen
  ///
  /// In en, this message translates to:
  /// **'Restore an existing wallet with your 12 or 24 words recovery phrase'**
  String get importWalletDescription;

  /// Hint for the recovery phrase text field
  ///
  /// In en, this message translates to:
  /// **'Type in or paste your recovery phrase. Separate words with spaces.'**
  String get importWalletHint;

  /// Import button on the import wallet screen
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importWalletButton;

  /// Validation error when recovery phrase word count is invalid
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase must be 12 or 24 words'**
  String get importWalletValidationError;

  /// Error message on the home screen
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String homeError(String error);

  /// Shown when no account is active on the home screen
  ///
  /// In en, this message translates to:
  /// **'No active account'**
  String get homeNoActiveAccount;

  /// POS charge button on the home screen bottom bar
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get homeCharge;

  /// Faucet button when balance is zero on the home screen
  ///
  /// In en, this message translates to:
  /// **'Get Testnet Tokens ↗'**
  String get homeGetTestnetTokens;

  /// Error when balance fails to load on the home screen
  ///
  /// In en, this message translates to:
  /// **'Error loading balance'**
  String get homeErrorLoadingBalance;

  /// Receive action button on the home screen
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get homeReceive;

  /// Send action button on the home screen
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get homeSend;

  /// Swap action button on the home screen
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get homeSwap;

  /// Section title for recent activity on the home screen
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get homeActivityTitle;

  /// Link to full activity screen from home
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeActivityViewAll;

  /// Error when transactions fail to load in home activity section
  ///
  /// In en, this message translates to:
  /// **'Error loading transactions'**
  String get homeActivityErrorLoading;

  /// Retry link in home activity section error state
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeActivityRetry;

  /// Empty state title in home activity section
  ///
  /// In en, this message translates to:
  /// **'No Transactions Yet'**
  String get homeActivityEmptyTitle;

  /// Empty state message in home activity section
  ///
  /// In en, this message translates to:
  /// **'Your activity will appear here once you send or receive QUAN.'**
  String get homeActivityEmptyMessage;

  /// Title of the accounts bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsSheetTitle;

  /// Error when accounts list fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load accounts.'**
  String get accountsSheetFailedLoadAccounts;

  /// Error when active account fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load active account.'**
  String get accountsSheetFailedLoadActiveAccount;

  /// Empty state in accounts sheet
  ///
  /// In en, this message translates to:
  /// **'No accounts found.'**
  String get accountsSheetNoAccountsFound;

  /// Button to add a new account
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get accountsSheetAddAccount;

  /// Loading balance in accounts sheet
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get accountsSheetLoading;

  /// When account balance fails to load
  ///
  /// In en, this message translates to:
  /// **'Balance unavailable'**
  String get accountsSheetBalanceUnavailable;

  /// Formatted balance with token symbol
  ///
  /// In en, this message translates to:
  /// **'{balance} {symbol}'**
  String accountsSheetBalance(String balance, String symbol);

  /// App bar title on add account menu
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccountMenuTitle;

  /// Create new account menu row title
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get addAccountMenuCreateTitle;

  /// Create new account menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Generate a fresh wallet address'**
  String get addAccountMenuCreateSubtitle;

  /// Import wallet menu row title
  ///
  /// In en, this message translates to:
  /// **'Import Wallet'**
  String get addAccountMenuImportTitle;

  /// Import wallet menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Use a recovery phrase to import'**
  String get addAccountMenuImportSubtitle;

  /// App bar title when creating an account
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get createAccountAppBarTitle;

  /// Subtitle on create account name field
  ///
  /// In en, this message translates to:
  /// **'Give this account a name you\'ll recognize. You can change it anytime.'**
  String get createAccountSubtitle;

  /// Create account button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createAccountButton;

  /// Error when account creation fails
  ///
  /// In en, this message translates to:
  /// **'Could not add account.'**
  String get createAccountErrorCouldNotAdd;

  /// Default name for a new account
  ///
  /// In en, this message translates to:
  /// **'Account {number}'**
  String createAccountDefaultName(int number);

  /// App bar title when editing account name
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get editAccountAppBarTitle;

  /// Done button on edit account screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editAccountDone;

  /// Validation error when account name is empty
  ///
  /// In en, this message translates to:
  /// **'Account name can\'t be empty'**
  String get editAccountNameEmpty;

  /// Error when renaming account fails
  ///
  /// In en, this message translates to:
  /// **'Failed to rename account.'**
  String get editAccountRenameFailed;

  /// App bar title on account menu screen
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountMenuTitle;

  /// Account name menu row label
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountMenuAccountName;

  /// Address details menu row label
  ///
  /// In en, this message translates to:
  /// **'Address Details'**
  String get accountMenuAddressDetails;

  /// Show recovery phrase menu row label
  ///
  /// In en, this message translates to:
  /// **'Show Recovery Phrase'**
  String get accountMenuShowRecoveryPhrase;

  /// When account is not found on menu screen
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get accountMenuNotFound;

  /// App bar title on account details screen
  ///
  /// In en, this message translates to:
  /// **'Address Details'**
  String get accountDetailsTitle;

  /// Title when adding a new hardware wallet
  ///
  /// In en, this message translates to:
  /// **'Add Hardware Wallet'**
  String get addHardwareAccountAddWallet;

  /// Title when adding a hardware account to existing wallet
  ///
  /// In en, this message translates to:
  /// **'Add Hardware Account'**
  String get addHardwareAccountAddAccount;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get addHardwareAccountNameLabel;

  /// Name field hint for new hardware wallet
  ///
  /// In en, this message translates to:
  /// **'Hardware Wallet'**
  String get addHardwareAccountNameHintWallet;

  /// Name field hint for hardware account
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get addHardwareAccountNameHintAccount;

  /// Address field label
  ///
  /// In en, this message translates to:
  /// **'ADDRESS'**
  String get addHardwareAccountAddressLabel;

  /// Address field hint
  ///
  /// In en, this message translates to:
  /// **'SS58 address'**
  String get addHardwareAccountAddressHint;

  /// Scan QR code button
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get addHardwareAccountScanQr;

  /// Debug fill button
  ///
  /// In en, this message translates to:
  /// **'Debug Fill'**
  String get addHardwareAccountDebugFill;

  /// Validation when name is empty
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get addHardwareAccountNameRequired;

  /// Validation when address is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid address'**
  String get addHardwareAccountInvalidAddress;

  /// Send flow app bar title
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTitle;

  /// Pay flow app bar title
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get sendPayTitle;

  /// Button label when recipient address is missing
  ///
  /// In en, this message translates to:
  /// **'Enter Address'**
  String get sendEnterAddress;

  /// Section label on select recipient screen
  ///
  /// In en, this message translates to:
  /// **'Send To'**
  String get sendSelectRecipientSendTo;

  /// Hint for recipient search field
  ///
  /// In en, this message translates to:
  /// **'Search {symbol} Address'**
  String sendSelectRecipientSearchHint(String symbol);

  /// Scan QR row title
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get sendSelectRecipientScanTitle;

  /// Scan QR row subtitle
  ///
  /// In en, this message translates to:
  /// **'Tap to scan a {symbol} Address'**
  String sendSelectRecipientScanSubtitle(String symbol);

  /// Recents section title
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get sendSelectRecipientRecents;

  /// Continue button on select recipient screen
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get sendSelectRecipientContinue;

  /// Recipient card label on input amount screen
  ///
  /// In en, this message translates to:
  /// **'SEND TO'**
  String get sendInputAmountSendTo;

  /// Available balance label
  ///
  /// In en, this message translates to:
  /// **'Available Balance:'**
  String get sendInputAmountAvailableBalance;

  /// Network fee label
  ///
  /// In en, this message translates to:
  /// **'Network Fee:'**
  String get sendInputAmountNetworkFee;

  /// Max amount button
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get sendInputAmountMax;

  /// Error when amount input is invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get sendInputAmountInvalidAmount;

  /// Error when recipient checksum is missing
  ///
  /// In en, this message translates to:
  /// **'Recipient checksum is required'**
  String get sendInputAmountChecksumRequired;

  /// Formatted balance with token symbol
  ///
  /// In en, this message translates to:
  /// **'{balance} {symbol}'**
  String sendInputAmountBalance(String balance, String symbol);

  /// Sending section label on review screen
  ///
  /// In en, this message translates to:
  /// **'SENDING'**
  String get sendReviewSending;

  /// To section label on review screen
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get sendReviewTo;

  /// Amount row label on review screen
  ///
  /// In en, this message translates to:
  /// **'AMOUNT'**
  String get sendReviewAmount;

  /// Network fee row label on review screen
  ///
  /// In en, this message translates to:
  /// **'NETWORK FEE'**
  String get sendReviewNetworkFee;

  /// Total you pay row label on review screen
  ///
  /// In en, this message translates to:
  /// **'YOU PAY'**
  String get sendReviewYouPay;

  /// Confirm button on review screen
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get sendReviewConfirm;

  /// Biometric auth prompt on review screen
  ///
  /// In en, this message translates to:
  /// **'Authenticate to confirm transaction'**
  String get sendReviewAuthReason;

  /// Error when auth fails on review screen
  ///
  /// In en, this message translates to:
  /// **'Authentication required to send'**
  String get sendReviewAuthRequired;

  /// Error when transaction submission fails
  ///
  /// In en, this message translates to:
  /// **'Failed submitting transaction'**
  String get sendReviewSubmitFailed;

  /// Success headline when payment completed
  ///
  /// In en, this message translates to:
  /// **'{amount} {symbol} paid'**
  String sendTxSubmittedHeadlinePaid(String amount, String symbol);

  /// Success headline when send completed
  ///
  /// In en, this message translates to:
  /// **'{amount} {symbol} sent'**
  String sendTxSubmittedHeadlineSent(String amount, String symbol);

  /// Subtitle on transaction submitted screen
  ///
  /// In en, this message translates to:
  /// **'On its way'**
  String get sendTxSubmittedOnItsWay;

  /// Recipient label on transaction submitted screen
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get sendTxSubmittedToLabel;

  /// Done button on transaction submitted screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sendTxSubmittedDone;

  /// Button label when sending to own address
  ///
  /// In en, this message translates to:
  /// **'Can\'t Self Transfer'**
  String get sendLogicCantSelfTransfer;

  /// Button label when amount is zero
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get sendLogicEnterAmount;

  /// Button label when amount is negative
  ///
  /// In en, this message translates to:
  /// **'Invalid Amount'**
  String get sendLogicInvalidAmount;

  /// Button label when amount is below existential deposit
  ///
  /// In en, this message translates to:
  /// **'Below Existential Deposit'**
  String get sendLogicBelowExistentialDeposit;

  /// Button label when balance is insufficient
  ///
  /// In en, this message translates to:
  /// **'Insufficient Balance'**
  String get sendLogicInsufficientBalance;

  /// Button label to proceed to review
  ///
  /// In en, this message translates to:
  /// **'Review Send'**
  String get sendLogicReviewSend;

  /// App bar title on activity screen
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// Error message on activity screen
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String activityError(String error);

  /// Shown when no account is active on activity screen
  ///
  /// In en, this message translates to:
  /// **'No account'**
  String get activityNoAccount;

  /// Empty state on activity screen
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get activityEmpty;

  /// Filter button for all transactions
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityFilterAll;

  /// Filter button for sent transactions
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get activityFilterSend;

  /// Filter button for received transactions
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get activityFilterReceive;

  /// Date group label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get activityDateToday;

  /// Date group label for yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get activityDateYesterday;

  /// Transaction row label for pending send
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get activityTxSending;

  /// Transaction row label for pending or scheduled receive
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get activityTxReceiving;

  /// Transaction row label for scheduled send
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get activityTxPending;

  /// Transaction row label for completed send
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get activityTxSent;

  /// Transaction row label for completed receive
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get activityTxReceived;

  /// Counterparty direction label for send
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get activityTxTo;

  /// Counterparty direction label for receive
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get activityTxFrom;

  /// Time label for just now
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get activityTxTimeNow;

  /// Time label for minutes ago
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String activityTxTimeMinutesAgo(int minutes);

  /// Time label for hours ago
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String activityTxTimeHoursAgo(int hours);

  /// Time label for days ago
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String activityTxTimeDaysAgo(int days);

  /// Time remaining for scheduled transaction
  ///
  /// In en, this message translates to:
  /// **'{days}d:{hours}h:{minutes}m'**
  String activityTxTimeRemaining(String days, String hours, String minutes);

  /// Detail sheet title for pending send
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get activityDetailTitleSending;

  /// Detail sheet title for scheduled send
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get activityDetailTitleScheduled;

  /// Detail sheet title for receiving
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get activityDetailTitleReceiving;

  /// Detail sheet title for completed send
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get activityDetailTitleSent;

  /// Detail sheet title for completed receive
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get activityDetailTitleReceived;

  /// Status label for in-process transaction
  ///
  /// In en, this message translates to:
  /// **'In Process'**
  String get activityDetailStatusInProcess;

  /// Status label for scheduled transaction
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get activityDetailStatusScheduled;

  /// Status label for completed transaction
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get activityDetailStatusCompleted;

  /// Status row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get activityDetailStatus;

  /// To row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get activityDetailTo;

  /// From row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get activityDetailFrom;

  /// Date row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get activityDetailDate;

  /// Network fee row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'NETWORK FEE'**
  String get activityDetailNetworkFee;

  /// Transaction hash row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'TX HASH'**
  String get activityDetailTxHash;

  /// Link to view transaction in explorer
  ///
  /// In en, this message translates to:
  /// **'View in Explorer ↗'**
  String get activityDetailViewExplorer;

  /// App bar title on receive screen
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

  /// QR Code tab on receive screen
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get receiveTabQrCode;

  /// Address tab on receive screen
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get receiveTabAddress;

  /// Copy button on receive screen
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get receiveCopy;

  /// Error when account data fails to load on receive screen
  ///
  /// In en, this message translates to:
  /// **'Error loading account data: {error}'**
  String receiveErrorLoadingAccount(String error);

  /// Clipboard content when copying account details
  ///
  /// In en, this message translates to:
  /// **'Account Id:\n{accountId}\n\nCheckphrase:\n{checksum}'**
  String receiveClipboardContent(String accountId, String checksum);

  /// Toast when account details are copied
  ///
  /// In en, this message translates to:
  /// **'Account details copied to clipboard'**
  String get receiveCopiedMessage;

  /// App bar title on POS amount screen
  ///
  /// In en, this message translates to:
  /// **'New Charge'**
  String get posAmountTitle;

  /// Charge button with formatted amount
  ///
  /// In en, this message translates to:
  /// **'Charge {amount}'**
  String posAmountCharge(String amount);

  /// Charge button when amount is empty
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get posAmountEnterAmount;

  /// App bar title while waiting for payment
  ///
  /// In en, this message translates to:
  /// **'Scan to Pay'**
  String get posQrTitleScanToPay;

  /// App bar title when payment is received
  ///
  /// In en, this message translates to:
  /// **'Payment Received'**
  String get posQrTitlePaymentReceived;

  /// Error message on POS QR screen
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String posQrError(String error);

  /// Shown when no active account on POS QR screen
  ///
  /// In en, this message translates to:
  /// **'No active account'**
  String get posQrNoActiveAccount;

  /// Error when amount cannot be parsed
  ///
  /// In en, this message translates to:
  /// **'Invalid amount. Tap to retry.'**
  String get posQrInvalidAmount;

  /// Error when payment watch connection is lost
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Tap to retry.'**
  String get posQrConnectionLost;

  /// Error when payment watch times out
  ///
  /// In en, this message translates to:
  /// **'Timed out. Tap to retry.'**
  String get posQrTimedOut;

  /// New charge button on POS QR screen
  ///
  /// In en, this message translates to:
  /// **'New Charge'**
  String get posQrNewCharge;

  /// Done button after payment received
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get posQrDone;

  /// Headline when payment is received
  ///
  /// In en, this message translates to:
  /// **'{amount} received'**
  String posQrAmountReceived(String amount);

  /// Sender label on payment received screen
  ///
  /// In en, this message translates to:
  /// **'From:'**
  String get posQrFrom;

  /// Status while waiting for payment
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment'**
  String get posQrWaitingForPayment;

  /// Network error title on POS QR screen
  ///
  /// In en, this message translates to:
  /// **'Network Error'**
  String get posQrNetworkError;

  /// Retry button on POS QR screen
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get posQrTryAgain;

  /// Paid at timestamp on payment received screen
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String posQrPaidAt(String time);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
