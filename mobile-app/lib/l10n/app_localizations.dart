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
