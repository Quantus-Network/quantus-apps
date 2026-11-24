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

  /// Overlay on the blurred recovery phrase grid
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get recoveryPhraseBodyTapToReveal;

  /// Hint below the revealed recovery phrase grid
  ///
  /// In en, this message translates to:
  /// **'Tap to hide'**
  String get recoveryPhraseBodyTapToHide;

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

  /// Subtitle on wallet created ready screen explaining the two accounts
  ///
  /// In en, this message translates to:
  /// **'Two accounts were created for you.'**
  String get accountReadyTwoAccountsCreated;

  /// Description under the transparent main account card after wallet creation
  ///
  /// In en, this message translates to:
  /// **'Your main account. Fast, visible on chain.'**
  String get accountReadyMainAccountDescription;

  /// Description under the encrypted account card after wallet creation
  ///
  /// In en, this message translates to:
  /// **'For private transactions. Shielded, slower.'**
  String get accountReadyEncryptedAccountDescription;

  /// Primary CTA on the wallet created ready screen
  ///
  /// In en, this message translates to:
  /// **'Go to Wallet'**
  String get accountReadyGoToWallet;

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

  /// Title of the dialog shown when looking up the imported wallet's accounts fails
  ///
  /// In en, this message translates to:
  /// **'Account scan failed'**
  String get importWalletScanFailedTitle;

  /// Body of the dialog shown when looking up the imported wallet's accounts fails
  ///
  /// In en, this message translates to:
  /// **'We could not reach the network to look for your accounts. Try again now, or skip and the app will scan again the next time it starts.'**
  String get importWalletScanFailedBody;

  /// Button that runs the account scan again
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get importWalletScanRetry;

  /// Button that finishes the import without scanning for accounts
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get importWalletScanSkip;

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

  /// Error when balance fails to load on the home screen
  ///
  /// In en, this message translates to:
  /// **'Error loading balance'**
  String get homeErrorLoadingBalance;

  /// Home banner prompting the user to back up their recovery phrase
  ///
  /// In en, this message translates to:
  /// **'Back up your recovery phrase'**
  String get homeBackupReminder;

  /// Full-width strip shown when the device is offline; rendered uppercase
  ///
  /// In en, this message translates to:
  /// **'Offline · showing last known balances'**
  String get networkStatusOfflineBanner;

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
  /// **'Your activity will appear here once you send or receive {tokenSymbol}.'**
  String homeActivityEmptyMessage(String tokenSymbol);

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

  /// Software wallet segment header in accounts sheet
  ///
  /// In en, this message translates to:
  /// **'Wallet {number}'**
  String accountsSheetWallet(int number);

  /// Keystone hardware wallet segment header in accounts sheet; the first wallet omits the number
  ///
  /// In en, this message translates to:
  /// **'{number, plural, =1{Cold Wallet} other{Cold Wallet {number}}}'**
  String accountsSheetKeystoneWallet(int number);

  /// Badge on the wallet header containing the active account; rendered uppercase
  ///
  /// In en, this message translates to:
  /// **'Active Wallet'**
  String get accountsScreenActiveWallet;

  /// Account count on a collapsed wallet row
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Account} other{{count} Accounts}}'**
  String accountsScreenAccountCount(int count);

  /// App bar title of the wallet naming screen
  ///
  /// In en, this message translates to:
  /// **'Wallet Name'**
  String get walletNameTitle;

  /// Explainer text on the wallet naming screen
  ///
  /// In en, this message translates to:
  /// **'Naming your wallets makes it easier to tell their accounts apart. Each wallet has its own encrypted account.'**
  String get walletNameSubtitle;

  /// Placeholder of the wallet name field
  ///
  /// In en, this message translates to:
  /// **'Enter a name for your wallet'**
  String get walletNameHint;

  /// App bar title on add account menu
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccountMenuTitle;

  /// Add transparent account menu row title
  ///
  /// In en, this message translates to:
  /// **'Add Transparent Account'**
  String get addAccountMenuCreateTitle;

  /// Add transparent account menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Add another public account'**
  String get addAccountMenuCreateSubtitle;

  /// Title of the add account more options action sheet
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get addAccountMenuMoreTitle;

  /// Add keystone hardware account menu row title
  ///
  /// In en, this message translates to:
  /// **'Add Cold Wallet'**
  String get addAccountMenuImportKeystoneTitle;

  /// Add keystone hardware account menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Air-gapped signing via QR code'**
  String get addAccountMenuImportKeystoneSubtitle;

  /// Import account menu row title
  ///
  /// In en, this message translates to:
  /// **'Import Account'**
  String get addAccountMenuImportTitle;

  /// Import account menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Restore from recovery phrase'**
  String get addAccountMenuImportSubtitle;

  /// Create multisig account menu row title
  ///
  /// In en, this message translates to:
  /// **'Create Multisig Account'**
  String get addAccountMenuMultisigTitle;

  /// Add multisig menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Set up a shared address with multiple signers'**
  String get addAccountMenuMultisigSubtitle;

  /// Add (discover) multisig menu row title
  ///
  /// In en, this message translates to:
  /// **'Add Multisig Account'**
  String get addAccountMenuDiscoverMultisigTitle;

  /// Discover multisig menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Find multisigs where your accounts are signers'**
  String get addAccountMenuDiscoverMultisigSubtitle;

  /// Badge label for multisig accounts
  ///
  /// In en, this message translates to:
  /// **'MULTISIG'**
  String get multisigTag;

  /// Propose flow app bar title and home CTA
  ///
  /// In en, this message translates to:
  /// **'Propose'**
  String get multisigProposeTitle;

  /// Create multisig screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Create Multisig'**
  String get multisigAddTitle;

  /// Discover multisig screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Discover Multisig'**
  String get multisigDiscoverTitle;

  /// Subtitle under multisig name field
  ///
  /// In en, this message translates to:
  /// **'Give this multisig a name you\'ll recognize. You can change it anytime.'**
  String get multisigCreateSubtitle;

  /// Primary button to create multisig
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get multisigCreateButton;

  /// Create button label while multisig creation is confirming on-chain
  ///
  /// In en, this message translates to:
  /// **'Creating'**
  String get multisigCreateCreatingButton;

  /// Default name for a new multisig
  ///
  /// In en, this message translates to:
  /// **'Multisig {number}'**
  String multisigCreateDefaultName(int number);

  /// Error toast when multisig creation fails
  ///
  /// In en, this message translates to:
  /// **'Could not create multisig.'**
  String get multisigCreateErrorCouldNotCreate;

  /// Toast when multisig creation is confirmed on-chain
  ///
  /// In en, this message translates to:
  /// **'Multisig added to your accounts.'**
  String get multisigCreateReadyToast;

  /// Toast when predicted multisig address is already registered
  ///
  /// In en, this message translates to:
  /// **'A multisig with this address already exists on-chain.'**
  String get multisigCreateAlreadyExists;

  /// Toast when creator balance is below pallet fee + network fee + deposit
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance to cover multisig creation fees.'**
  String get multisigCreateInsufficientBalance;

  /// Toast when on-chain confirmation polling times out
  ///
  /// In en, this message translates to:
  /// **'Multisig creation is taking longer than expected. Check the chain or try again.'**
  String get multisigCreateTimeoutToast;

  /// Local auth prompt when submitting create multisig
  ///
  /// In en, this message translates to:
  /// **'Authenticate to create this multisig'**
  String get multisigCreateAuthReason;

  /// Section label for signer list on create multisig
  ///
  /// In en, this message translates to:
  /// **'SIGNERS'**
  String get multisigCreateSignersLabel;

  /// Helper text under signers section on create multisig
  ///
  /// In en, this message translates to:
  /// **'Add at least one other signer besides yourself.'**
  String get multisigCreateSignersSubtitle;

  /// Hint for adding a signer address
  ///
  /// In en, this message translates to:
  /// **'Signer address'**
  String get multisigCreateAddSignerHint;

  /// Button to add a signer from address field
  ///
  /// In en, this message translates to:
  /// **'Add Signer'**
  String get multisigCreateAddSignerButton;

  /// Error when signer address is duplicate
  ///
  /// In en, this message translates to:
  /// **'This signer is already in the list.'**
  String get multisigCreateDuplicateSigner;

  /// Error when signer address is invalid
  ///
  /// In en, this message translates to:
  /// **'Enter a valid signer address.'**
  String get multisigCreateInvalidSigner;

  /// Error when an added signer address is one of this wallet's multisig accounts
  ///
  /// In en, this message translates to:
  /// **'This address is a multisig account. A multisig cannot sign, so this signer cannot approve in this wallet. If the remaining members cannot meet the threshold, funds in that multisig may need recovery through the CLI.'**
  String get multisigCreateSignerIsMultisig;

  /// Threshold slider section label on create multisig
  ///
  /// In en, this message translates to:
  /// **'THRESHOLD'**
  String get multisigCreateThresholdLabel;

  /// Threshold slider value label
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String multisigCreateThresholdValue(int count, int total);

  /// What a Keystone creator is signing, shown on the Keystone sign and verify screens
  ///
  /// In en, this message translates to:
  /// **'Create {count} of {total} multisig'**
  String multisigCreateKeystoneAction(int count, int total);

  /// Label for predicted multisig address preview
  ///
  /// In en, this message translates to:
  /// **'MULTISIG ADDRESS'**
  String get multisigCreatePredictedAddressLabel;

  /// Placeholder when predicted address is not yet available
  ///
  /// In en, this message translates to:
  /// **'Add signers to preview address'**
  String get multisigCreatePredictedAddressPlaceholder;

  /// Done button on multisig flow completion screens
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get multisigDone;

  /// Section title for on-chain discovered multisigs
  ///
  /// In en, this message translates to:
  /// **'Discovered for you'**
  String get multisigAddDiscoveredTitle;

  /// Helper text under discovered multisigs section
  ///
  /// In en, this message translates to:
  /// **'Multisigs on chain where one of your accounts is a signer'**
  String get multisigAddDiscoveredSubtitle;

  /// Add button on discovered multisig row
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get multisigAddButton;

  /// Disabled state when multisig is already added
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get multisigAddedButton;

  /// Empty state when no multisigs are discovered
  ///
  /// In en, this message translates to:
  /// **'No multisigs found.'**
  String get multisigAddNoneFound;

  /// Error when multisig discovery fails
  ///
  /// In en, this message translates to:
  /// **'Could not discover multisigs: {error}'**
  String multisigAddDiscoverFailed(String error);

  /// Error when adding a multisig fails
  ///
  /// In en, this message translates to:
  /// **'Could not add multisig: {error}'**
  String multisigAddFailed(String error);

  /// Section title for open multisig proposals
  ///
  /// In en, this message translates to:
  /// **'Open Proposals'**
  String get multisigOpenProposals;

  /// Section title for past multisig proposals
  ///
  /// In en, this message translates to:
  /// **'Past Proposals'**
  String get multisigPastProposals;

  /// Empty state for open proposals list
  ///
  /// In en, this message translates to:
  /// **'No open proposals.'**
  String get multisigNoOpenProposals;

  /// Empty state for past proposals list
  ///
  /// In en, this message translates to:
  /// **'No past proposals.'**
  String get multisigNoPastProposals;

  /// Error when proposal list fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String multisigLoadFailed(String error);

  /// Proposal row recipient line
  ///
  /// In en, this message translates to:
  /// **'to {address}'**
  String multisigProposalToAddress(String address);

  /// Shown while the proposal's stored call bytes are being fetched before approving
  ///
  /// In en, this message translates to:
  /// **'Reading the proposal from the chain…'**
  String get multisigProposalCallLoading;

  /// Shown when the proposal's stored call bytes could not be fetched, blocking approval
  ///
  /// In en, this message translates to:
  /// **'Could not read this proposal from the chain, so there is nothing to approve. Try again when you are back online.'**
  String get multisigProposalCallUnavailable;

  /// Shown in place of the amount when the proposal's stored call bytes cannot be decoded, blocking approval
  ///
  /// In en, this message translates to:
  /// **'Invalid proposal'**
  String get multisigProposalInvalid;

  /// Proposal status chip when the current signer has approved
  ///
  /// In en, this message translates to:
  /// **'SIGNED'**
  String get multisigStatusApproved;

  /// Proposal status chip when the current signer has not approved yet
  ///
  /// In en, this message translates to:
  /// **'PROPOSED'**
  String get multisigStatusProposed;

  /// Proposal status chip when expired
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get multisigStatusExpired;

  /// Proposal status chip when cancelled
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get multisigStatusCancelled;

  /// Section label on propose recipient screen — transfer destination
  ///
  /// In en, this message translates to:
  /// **'Transfer to'**
  String get multisigProposeSelectRecipientTo;

  /// Hint for recipient search field on propose flow
  ///
  /// In en, this message translates to:
  /// **'Enter {symbol} Address'**
  String multisigProposeSearchHint(String symbol);

  /// Recipient card label on propose amount screen
  ///
  /// In en, this message translates to:
  /// **'TRANSFER TO'**
  String get multisigProposeAmountToLabel;

  /// Refundable proposal deposit label on propose amount screen
  ///
  /// In en, this message translates to:
  /// **'Deposit:'**
  String get multisigProposeDepositLabel;

  /// Non-refundable burned proposal fee label (scales with signers)
  ///
  /// In en, this message translates to:
  /// **'Proposal Fee:'**
  String get multisigProposeCreationFeeLabel;

  /// Short note that proposal deposit is returned on execute/cancel
  ///
  /// In en, this message translates to:
  /// **'refundable'**
  String get multisigProposeDepositRefundableNote;

  /// Review row for total member cost at proposal submit
  ///
  /// In en, this message translates to:
  /// **'TOTAL FROM YOUR ACCOUNT'**
  String get multisigProposeMemberTotalLabel;

  /// Deprecated single fee label; prefer fee breakdown labels
  ///
  /// In en, this message translates to:
  /// **'Proposal Fee:'**
  String get multisigProposeFeeLabel;

  /// Shown when proposal fee estimation fails on the amount screen
  ///
  /// In en, this message translates to:
  /// **'Unable to estimate fee'**
  String get multisigProposeFeeFetchFailed;

  /// Label for the proposing member's balance on the amount screen
  ///
  /// In en, this message translates to:
  /// **'Your Balance:'**
  String get multisigProposeFeePayerBalanceLabel;

  /// Button text when proposer cannot afford the proposal fee
  ///
  /// In en, this message translates to:
  /// **'Insufficient Balance for Fee'**
  String get multisigProposeFeePayerInsufficient;

  /// Row label for the proposer address on the propose review screen
  ///
  /// In en, this message translates to:
  /// **'PROPOSER'**
  String get multisigProposeProposerLabel;

  /// Button to open propose review screen
  ///
  /// In en, this message translates to:
  /// **'Review transfer'**
  String get multisigProposeReviewButton;

  /// Hero label on propose review screen
  ///
  /// In en, this message translates to:
  /// **'PROPOSED TRANSFER'**
  String get multisigProposeReviewProposing;

  /// Multisig name on propose review hero card
  ///
  /// In en, this message translates to:
  /// **'from {name}'**
  String multisigProposeReviewFromName(String name);

  /// Threshold row label on propose review
  ///
  /// In en, this message translates to:
  /// **'THRESHOLD'**
  String get multisigProposeThresholdLabel;

  /// Expiry row label on propose review
  ///
  /// In en, this message translates to:
  /// **'EXPIRES'**
  String get multisigProposeExpiresLabel;

  /// On-chain expiry block when current block is unavailable
  ///
  /// In en, this message translates to:
  /// **'Block {block}'**
  String multisigExpiresBlockOnly(int block);

  /// Non-refundable burned proposal fee row on propose review
  ///
  /// In en, this message translates to:
  /// **'PROPOSAL FEE'**
  String get multisigProposeFeeRowLabel;

  /// Submit button on propose review screen
  ///
  /// In en, this message translates to:
  /// **'Submit proposal'**
  String get multisigProposeCreateButton;

  /// Biometric auth prompt when creating a proposal
  ///
  /// In en, this message translates to:
  /// **'Authenticate to propose transaction'**
  String get multisigProposeAuthReason;

  /// Error when auth fails on propose review
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get multisigProposeAuthRequired;

  /// Error when proposal creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create proposal'**
  String get multisigProposeSubmitFailed;

  /// Toast when proposal indexing polling times out
  ///
  /// In en, this message translates to:
  /// **'Proposal confirmation is taking longer than expected. Check the chain or try again.'**
  String get multisigProposeTimeoutToast;

  /// Success headline on propose done screen
  ///
  /// In en, this message translates to:
  /// **'Transfer proposal submitted'**
  String get multisigProposeDoneHeadline;

  /// Success subline on propose done screen
  ///
  /// In en, this message translates to:
  /// **'Co-signers must approve before the transfer can execute.'**
  String get multisigProposeDoneSubline;

  /// Recipient checksum line on propose done screen
  ///
  /// In en, this message translates to:
  /// **'to {checksum}'**
  String multisigProposeDoneToChecksum(String checksum);

  /// Approval count on propose or approve done screen
  ///
  /// In en, this message translates to:
  /// **'Signatures: {current}/{threshold}'**
  String multisigSignaturesCount(int current, int threshold);

  /// App bar title on proposal detail screen
  ///
  /// In en, this message translates to:
  /// **'Proposal'**
  String get multisigProposalTitle;

  /// Error when proposal detail fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String multisigProposalLoadFailed(String error);

  /// Empty state when proposal id is missing
  ///
  /// In en, this message translates to:
  /// **'Proposal not found.'**
  String get multisigProposalNotFound;

  /// Sign button on the read-only proposal detail sheet
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get multisigProposalSignButton;

  /// Deprecated; kept for generated l10n compatibility
  ///
  /// In en, this message translates to:
  /// **'Signing will be available soon.'**
  String get multisigProposalSigningSoonNote;

  /// Disabled approve button while approval is pending indexer confirmation
  ///
  /// In en, this message translates to:
  /// **'Approving…'**
  String get multisigProposalApprovingLabel;

  /// Note under the button while approval is pending
  ///
  /// In en, this message translates to:
  /// **'Your approval is being confirmed on-chain.'**
  String get multisigProposalApprovingNote;

  /// Note when approve is unavailable (expired or closed)
  ///
  /// In en, this message translates to:
  /// **'This proposal can no longer be approved.'**
  String get multisigApproveUnavailableNote;

  /// Trailing label on proposal row while approval is pending
  ///
  /// In en, this message translates to:
  /// **'Approving…'**
  String get activityTxApproving;

  /// Trailing label on proposal row while cancellation is pending
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get activityTxCancelling;

  /// Toast when approval indexer polling times out
  ///
  /// In en, this message translates to:
  /// **'Approval confirmation is taking longer than expected. Check the chain or try again.'**
  String get multisigApprovalTimeoutToast;

  /// Note shown when the current member already approved
  ///
  /// In en, this message translates to:
  /// **'You\'ve already signed this proposal.'**
  String get multisigProposalAlreadySignedNote;

  /// Note shown on proposal detail when the proposal is executed
  ///
  /// In en, this message translates to:
  /// **'This proposal is already executed.'**
  String get multisigProposalAlreadyExecutedNote;

  /// Note shown on proposal detail when the proposal is cancelled
  ///
  /// In en, this message translates to:
  /// **'This proposal is already cancelled.'**
  String get multisigProposalAlreadyCancelledNote;

  /// Proposer row label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'PROPOSER'**
  String get multisigProposalProposerLabel;

  /// Status row label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get multisigProposalStatusLabel;

  /// Deposit row label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'DEPOSIT'**
  String get multisigProposalDepositLabel;

  /// Active proposal status label
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get multisigStatusActive;

  /// Executed proposal status label
  ///
  /// In en, this message translates to:
  /// **'EXECUTED'**
  String get multisigStatusExecuted;

  /// Removed proposal status label
  ///
  /// In en, this message translates to:
  /// **'REMOVED'**
  String get multisigStatusRemoved;

  /// Unknown proposal status label when indexer returns an unrecognized value
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get multisigStatusUnknown;

  /// Activity row label for an indexed multisig proposal
  ///
  /// In en, this message translates to:
  /// **'Proposal'**
  String get activityTxProposal;

  /// Activity row label for a pending multisig proposal
  ///
  /// In en, this message translates to:
  /// **'Proposing'**
  String get activityTxProposing;

  /// Activity row label for a confirmed multisig proposal creation on the proposer account
  ///
  /// In en, this message translates to:
  /// **'Proposal created'**
  String get activityTxProposalCreated;

  /// Activity row label for a confirmed multisig proposal approval on the approver account
  ///
  /// In en, this message translates to:
  /// **'Proposal approved'**
  String get activityTxProposalApproved;

  /// Activity row label for a confirmed multisig proposal execution on the executor account
  ///
  /// In en, this message translates to:
  /// **'Proposal executed'**
  String get activityTxProposalExecuted;

  /// Activity row label for a confirmed multisig proposal cancellation on the proposer account
  ///
  /// In en, this message translates to:
  /// **'Proposal cancelled'**
  String get activityTxProposalCancelled;

  /// Activity row label for a multisig proposal that expired and was removed
  ///
  /// In en, this message translates to:
  /// **'Proposal removed'**
  String get activityTxProposalRemoved;

  /// Approve button on proposal detail
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get multisigApproveButton;

  /// Disabled approve button when user already signed
  ///
  /// In en, this message translates to:
  /// **'Already Signed'**
  String get multisigAlreadyApproved;

  /// Title on sheet for picking which local signer approves a proposal
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get multisigSignerPickerTitle;

  /// Body text on multi-local-signer approve picker sheet
  ///
  /// In en, this message translates to:
  /// **'Multiple accounts on this device can sign. Choose which one to approve with.'**
  String get multisigSignerPickerBody;

  /// Cancel proposal button on detail screen
  ///
  /// In en, this message translates to:
  /// **'Cancel Proposal'**
  String get multisigCancelProposalButton;

  /// Expires row label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'EXPIRES'**
  String get multisigProposalExpiresLabel;

  /// Timestamp row label on past proposal detail
  ///
  /// In en, this message translates to:
  /// **'AT'**
  String get multisigProposalAtLabel;

  /// Threshold row label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'THRESHOLD'**
  String get multisigProposalThresholdLabel;

  /// Approvals row label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'APPROVALS'**
  String get multisigProposalApprovalsLabel;

  /// Proposal fee row label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'PROPOSAL FEE'**
  String get multisigProposalFeeRowLabel;

  /// Signers section label on proposal detail
  ///
  /// In en, this message translates to:
  /// **'SIGNERS'**
  String get multisigProposalSignersLabel;

  /// Badge on current user in signers list
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get multisigYouLabel;

  /// Badge on multisig creator in signers list
  ///
  /// In en, this message translates to:
  /// **'CREATOR'**
  String get multisigSignerCreatorLabel;

  /// Menu row to view multisig threshold and signers
  ///
  /// In en, this message translates to:
  /// **'Multisig details'**
  String get multisigAccountMenuDetails;

  /// App bar title on multisig details screen
  ///
  /// In en, this message translates to:
  /// **'Multisig details'**
  String get multisigAccountMenuDetailsTitle;

  /// Helper text under threshold on multisig details screen
  ///
  /// In en, this message translates to:
  /// **'This many signer approvals are required to execute a proposal.'**
  String get multisigAccountMenuDetailsThresholdHint;

  /// Threshold value on proposal detail
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String multisigThresholdOf(int count, int total);

  /// Approvals value on proposal detail
  ///
  /// In en, this message translates to:
  /// **'{count} of {threshold}'**
  String multisigApprovalsOf(int count, int threshold);

  /// Title on approve confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get multisigApproveConfirmTitle;

  /// Body text on approve confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'You are about to approve a transfer of'**
  String get multisigApproveConfirmBody;

  /// Recipient line on approve confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'to {address}'**
  String multisigApproveConfirmTo(String address);

  /// Confirm button on approve sheet
  ///
  /// In en, this message translates to:
  /// **'Yes, Approve'**
  String get multisigApproveConfirmYes;

  /// Dismiss button on approve sheet
  ///
  /// In en, this message translates to:
  /// **'No, Go Back'**
  String get multisigApproveConfirmNo;

  /// Biometric auth prompt when approving
  ///
  /// In en, this message translates to:
  /// **'Authenticate to approve'**
  String get multisigApproveAuthReason;

  /// Error when auth fails on a multisig action
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get multisigAuthRequired;

  /// Error when approve submission fails
  ///
  /// In en, this message translates to:
  /// **'Failed to approve'**
  String get multisigApproveFailed;

  /// Button to execute an approved multisig proposal
  ///
  /// In en, this message translates to:
  /// **'Execute'**
  String get multisigExecuteButton;

  /// Title on execute confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get multisigExecuteConfirmTitle;

  /// Body text on execute confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'You are about to execute a transfer of'**
  String get multisigExecuteConfirmBody;

  /// Confirm button on execute sheet
  ///
  /// In en, this message translates to:
  /// **'Yes, Execute'**
  String get multisigExecuteConfirmYes;

  /// Biometric auth prompt when executing
  ///
  /// In en, this message translates to:
  /// **'Authenticate to execute'**
  String get multisigExecuteAuthReason;

  /// Error when execute submission fails
  ///
  /// In en, this message translates to:
  /// **'Failed to execute'**
  String get multisigExecuteFailed;

  /// Note when execute action is unavailable
  ///
  /// In en, this message translates to:
  /// **'This proposal can no longer be executed.'**
  String get multisigExecuteUnavailableNote;

  /// Disabled execute button while pending
  ///
  /// In en, this message translates to:
  /// **'Executing…'**
  String get multisigProposalExecutingLabel;

  /// Note while execution is pending indexer confirmation
  ///
  /// In en, this message translates to:
  /// **'Your execution is being confirmed on-chain.'**
  String get multisigProposalExecutingNote;

  /// Status label on proposal row while execution is pending
  ///
  /// In en, this message translates to:
  /// **'Executing…'**
  String get activityTxExecuting;

  /// Toast when execution indexer polling times out
  ///
  /// In en, this message translates to:
  /// **'Execution confirmation is taking longer than expected. Check the chain or try again.'**
  String get multisigExecutionTimeoutToast;

  /// Toast when a proposal is executed but not by this user's extrinsic
  ///
  /// In en, this message translates to:
  /// **'Proposal was executed by another signer.'**
  String get multisigExecutedByOtherToast;

  /// Inline note on confirm sheet when fee estimation fails
  ///
  /// In en, this message translates to:
  /// **'Network fee estimate is unavailable.'**
  String get multisigFeeEstimateUnavailable;

  /// Title on cancel confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Cancel Proposal?'**
  String get multisigCancelConfirmTitle;

  /// Explanation on cancel confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Cancelling refunds your proposal deposit. Other signers will no longer be able to approve.'**
  String get multisigCancelConfirmBody;

  /// Confirm cancel button
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel Proposal'**
  String get multisigCancelConfirmYes;

  /// Dismiss cancel button
  ///
  /// In en, this message translates to:
  /// **'Keep Proposal'**
  String get multisigCancelConfirmKeep;

  /// Biometric auth prompt when cancelling
  ///
  /// In en, this message translates to:
  /// **'Authenticate to cancel'**
  String get multisigCancelAuthReason;

  /// Error when cancel submission fails
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel'**
  String get multisigCancelFailed;

  /// Cancel button label while cancellation is pending
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get multisigProposalCancellingLabel;

  /// Note under the button while cancellation is pending
  ///
  /// In en, this message translates to:
  /// **'Your cancellation is being confirmed on-chain.'**
  String get multisigProposalCancellingNote;

  /// Toast when cancellation indexer polling times out
  ///
  /// In en, this message translates to:
  /// **'Cancellation confirmation is taking longer than expected. Check the chain or try again.'**
  String get multisigCancelTimeoutToast;

  /// App bar title on approve done screen
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get multisigApproveTitle;

  /// Headline when threshold reached after approve
  ///
  /// In en, this message translates to:
  /// **'Proposal executed'**
  String get multisigApproveDoneExecuted;

  /// Headline when approval recorded but threshold not met
  ///
  /// In en, this message translates to:
  /// **'Approval recorded'**
  String get multisigApproveDoneRecorded;

  /// Subline when proposal executed
  ///
  /// In en, this message translates to:
  /// **'Threshold reached — transfer dispatched.'**
  String get multisigApproveDoneExecutedSubline;

  /// Subline when awaiting more approvals
  ///
  /// In en, this message translates to:
  /// **'Awaiting more co-signers.'**
  String get multisigApproveDoneRecordedSubline;

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

  /// Default name for a newly created encrypted account
  ///
  /// In en, this message translates to:
  /// **'Encrypted Account'**
  String get createAccountEncryptedDefaultName;

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

  /// Menu row label shown for encrypted accounts instead of address details
  ///
  /// In en, this message translates to:
  /// **'Inner Hash'**
  String get accountMenuInnerHash;

  /// Show recovery phrase menu row label
  ///
  /// In en, this message translates to:
  /// **'Show Recovery Phrase'**
  String get accountMenuShowRecoveryPhrase;

  /// Account row menu item opening the address details
  ///
  /// In en, this message translates to:
  /// **'Show address'**
  String get accountMenuShowAddress;

  /// Account and wallet row menu item opening the name editor
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get accountMenuRename;

  /// Destructive account row menu item
  ///
  /// In en, this message translates to:
  /// **'Disconnect account'**
  String get accountMenuDisconnectAccount;

  /// When account is not found on menu screen
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get accountMenuNotFound;

  /// Done button shown on the account overview right after creating an account
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get accountMenuDone;

  /// Disconnect (stop tracking) button on hardware wallet and multisig overview
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get accountMenuDisconnect;

  /// Title of the hardware wallet disconnect confirmation
  ///
  /// In en, this message translates to:
  /// **'Disconnect hardware wallet?'**
  String get accountMenuDisconnectHardwareTitle;

  /// Body of the hardware wallet disconnect confirmation
  ///
  /// In en, this message translates to:
  /// **'This stops tracking \"{name}\" on this device. Your hardware wallet keeps the account, so you can reconnect it anytime.'**
  String accountMenuDisconnectHardwareMessage(String name);

  /// Title of the multisig disconnect confirmation
  ///
  /// In en, this message translates to:
  /// **'Disconnect multisig?'**
  String get accountMenuDisconnectMultisigTitle;

  /// Body of the multisig disconnect confirmation
  ///
  /// In en, this message translates to:
  /// **'This stops tracking \"{name}\" on this device. The multisig stays on-chain, so you can re-add it anytime.'**
  String accountMenuDisconnectMultisigMessage(String name);

  /// Error toaster shown when disconnecting an account fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t disconnect. Please try again.'**
  String get accountMenuDisconnectError;

  /// Title of the software account disconnect confirmation
  ///
  /// In en, this message translates to:
  /// **'Disconnect account?'**
  String get accountMenuDisconnectAccountTitle;

  /// Body of the software account disconnect confirmation
  ///
  /// In en, this message translates to:
  /// **'This stops tracking \"{name}\" on this device. Your recovery phrase stays, so you can restore it later.'**
  String accountMenuDisconnectAccountMessage(String name);

  /// Title shown when disconnecting the last account in a wallet, which removes the whole wallet
  ///
  /// In en, this message translates to:
  /// **'Disconnect Wallet {number}?'**
  String accountMenuDisconnectWalletTitle(int number);

  /// Body shown when disconnecting the last account in a wallet
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is the last account in Wallet {number}. Disconnecting it removes the entire wallet from this device.'**
  String accountMenuDisconnectWalletMessage(String name, int number);

  /// Confirm button for disconnecting an entire wallet
  ///
  /// In en, this message translates to:
  /// **'Disconnect Wallet'**
  String get accountMenuDisconnectWalletConfirm;

  /// Title of the final confirmation before permanently deleting a wallet
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get accountMenuDeleteWalletTitle;

  /// Body of the final confirmation before permanently deleting a wallet's seed phrase
  ///
  /// In en, this message translates to:
  /// **'Wallet {number}\'s recovery phrase will be permanently deleted from this device. Make sure it\'s backed up — this can\'t be undone.'**
  String accountMenuDeleteWalletMessage(int number);

  /// Confirm button for permanently deleting a wallet and its recovery phrase
  ///
  /// In en, this message translates to:
  /// **'Delete Wallet'**
  String get accountMenuDeleteWalletConfirm;

  /// App bar title on account details screen
  ///
  /// In en, this message translates to:
  /// **'Address Details'**
  String get accountDetailsTitle;

  /// App bar title on the encrypted account inner hash screen
  ///
  /// In en, this message translates to:
  /// **'Inner Hash'**
  String get innerHashTitle;

  /// Card label above the inner hash value
  ///
  /// In en, this message translates to:
  /// **'INNER HASH'**
  String get innerHashLabel;

  /// Toaster shown after copying the inner hash
  ///
  /// In en, this message translates to:
  /// **'Inner hash copied'**
  String get innerHashCopied;

  /// Toaster shown when deriving the inner hash fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load inner hash'**
  String get innerHashLoadError;

  /// App bar title for the add Keystone wallet screens
  ///
  /// In en, this message translates to:
  /// **'Add Cold Wallet'**
  String get addKeystoneAppBarTitle;

  /// Headline on the add Keystone intro screen
  ///
  /// In en, this message translates to:
  /// **'Cold Wallet'**
  String get addKeystoneIntroTitle;

  /// Subtitle on the add Keystone intro screen
  ///
  /// In en, this message translates to:
  /// **'An air-gapped wallet that talks to this app only through QR codes. Keys never leave the device.'**
  String get addKeystoneIntroSubtitle;

  /// Primary button on the add Keystone intro screen
  ///
  /// In en, this message translates to:
  /// **'Connect Cold Wallet'**
  String get addKeystoneConnectButton;

  /// Headline on the Keystone connect instructions screen
  ///
  /// In en, this message translates to:
  /// **'Connect Cold Wallet'**
  String get addKeystoneConnectTitle;

  /// Subtitle on the Keystone connect instructions screen
  ///
  /// In en, this message translates to:
  /// **'Scan your device\'s QR code to connect.'**
  String get addKeystoneConnectSubtitle;

  /// Section label for the on-device steps
  ///
  /// In en, this message translates to:
  /// **'ON YOUR COLD WALLET'**
  String get addKeystoneOnYourKeystone;

  /// On-device step: unlock
  ///
  /// In en, this message translates to:
  /// **'Unlock your cold wallet'**
  String get addKeystoneStepUnlock;

  /// On-device step: select Quantus and scan
  ///
  /// In en, this message translates to:
  /// **'Show your account QR code'**
  String get addKeystoneStepSelectQuantus;

  /// Primary button opening the QR scanner on the Keystone connect instructions screen
  ///
  /// In en, this message translates to:
  /// **'Ready to Scan'**
  String get addKeystoneReadyToScan;

  /// Shown when an address fails SS58 validation
  ///
  /// In en, this message translates to:
  /// **'Invalid address'**
  String get invalidAddress;

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
  /// **'Enter {symbol} Address'**
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

  /// Label for balance that is not yet spendable (encrypted change awaiting the indexer)
  ///
  /// In en, this message translates to:
  /// **'Pending:'**
  String get sendInputAmountPending;

  /// Network fee label
  ///
  /// In en, this message translates to:
  /// **'Transaction Fee:'**
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

  /// Toast when a send is requested while the active account cannot make regular transfers
  ///
  /// In en, this message translates to:
  /// **'Switch to a regular account to send'**
  String get sendRegularAccountRequired;

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

  /// App bar title shared by the Keystone signing screens
  ///
  /// In en, this message translates to:
  /// **'Sign with Cold Wallet'**
  String get keystoneSignScreenTitle;

  /// Step indicator on the Keystone signing screens
  ///
  /// In en, this message translates to:
  /// **'STEP {current}/{total}'**
  String keystoneSignStep(int current, int total);

  /// Title on the Keystone sign screen showing the unsigned transaction QR
  ///
  /// In en, this message translates to:
  /// **'Scan with your cold wallet'**
  String get keystoneSignTitle;

  /// Instruction on the Keystone sign screen
  ///
  /// In en, this message translates to:
  /// **'Open your cold wallet and scan this QR code to load the transaction.'**
  String get keystoneSignInstruction;

  /// Label for a non-transfer action on the Keystone sign and verify screens
  ///
  /// In en, this message translates to:
  /// **'ACTION'**
  String get keystoneSignActionLabel;

  /// Section label above the transaction details on the Keystone sign screen
  ///
  /// In en, this message translates to:
  /// **'YOU ARE SIGNING'**
  String get keystoneSignYouAreSigning;

  /// Button to advance to the next Keystone signing step
  ///
  /// In en, this message translates to:
  /// **'Continue to Sign'**
  String get keystoneSignNext;

  /// Link to abort the Keystone signing flow
  ///
  /// In en, this message translates to:
  /// **'Cancel Transaction'**
  String get keystoneSignCancel;

  /// Error when building the unsigned transaction payload fails
  ///
  /// In en, this message translates to:
  /// **'Failed to prepare the transaction. Please try again.'**
  String get keystoneSignError;

  /// Title on the Keystone verification screen
  ///
  /// In en, this message translates to:
  /// **'Check your Cold Wallet Screen'**
  String get keystoneVerifyTitle;

  /// Instruction on the Keystone verification screen
  ///
  /// In en, this message translates to:
  /// **'Before approving on your cold wallet, make sure its screen shows exactly this:'**
  String get keystoneVerifyInstruction;

  /// Warning shown when asking the user to compare the Keystone screen
  ///
  /// In en, this message translates to:
  /// **'If the amount or address on your cold wallet screen is different from what\'s shown here, reject the transaction on your device.'**
  String get keystoneVerifyWarning;

  /// Link opening the mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'It doesn\'t match'**
  String get keystoneVerifyMismatch;

  /// Title on the Keystone signature scanner screen
  ///
  /// In en, this message translates to:
  /// **'Scan the signature'**
  String get keystoneScanTitle;

  /// Instruction on the Keystone signature scanner screen
  ///
  /// In en, this message translates to:
  /// **'Your cold wallet is now showing an animated QR. Hold your phone up to it, this takes a moment.'**
  String get keystoneScanInstruction;

  /// Label next to the scan progress on the Keystone signature scanner screen
  ///
  /// In en, this message translates to:
  /// **'RECEIVING SIGNATURE'**
  String get keystoneScanReceiving;

  /// Overlay text while the externally signed transaction is broadcast
  ///
  /// In en, this message translates to:
  /// **'Submitting transaction...'**
  String get keystoneScanSubmitting;

  /// Error when decoding or submitting the scanned signature fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the signature. Please try again.'**
  String get keystoneScanError;

  /// Error when the mortal era window closed before the signed transaction was submitted
  ///
  /// In en, this message translates to:
  /// **'The transaction expired before it could be submitted. Go back and scan the new QR code with your device.'**
  String get keystoneScanExpired;

  /// Headline on the Keystone mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'Don\'t approve this transaction'**
  String get keystoneRejectTitle;

  /// First step title on the Keystone mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'Reject the transaction on your cold wallet.'**
  String get keystoneRejectStep1Title;

  /// First step body on the Keystone mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'Nothing is signed or sent until you approve there.'**
  String get keystoneRejectStep1Body;

  /// Second step title on the Keystone mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'Don\'t retry from this phone.'**
  String get keystoneRejectStep2Title;

  /// Second step body on the Keystone mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'If it\'s compromised, retrying gives the attacker another chance.'**
  String get keystoneRejectStep2Body;

  /// Third step title on the Keystone mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'Your funds are safe on the cold wallet.'**
  String get keystoneRejectStep3Title;

  /// Third step body on the Keystone mismatch help screen
  ///
  /// In en, this message translates to:
  /// **'Keys never left the device. Move to a trusted phone before sending again.'**
  String get keystoneRejectStep3Body;

  /// Button confirming the transaction was rejected on the device
  ///
  /// In en, this message translates to:
  /// **'I rejected it on the cold wallet'**
  String get keystoneRejectConfirm;

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

  /// Button label when amount is below the minimum send amount (one wormhole leaf quantum)
  ///
  /// In en, this message translates to:
  /// **'Minimum is {amount} {tokenSymbol}'**
  String sendLogicBelowMinimum(String amount, String tokenSymbol);

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

  /// Transaction row label for pending encrypted send
  ///
  /// In en, this message translates to:
  /// **'Privately Sending'**
  String get activityTxPrivatelySending;

  /// Transaction row label for pending encrypted receive
  ///
  /// In en, this message translates to:
  /// **'Privately Receiving'**
  String get activityTxPrivatelyReceiving;

  /// Transaction row label for completed encrypted send
  ///
  /// In en, this message translates to:
  /// **'Private Sent'**
  String get activityTxPrivateSent;

  /// Transaction row label for completed encrypted receive
  ///
  /// In en, this message translates to:
  /// **'Private Received'**
  String get activityTxPrivateReceived;

  /// Transaction row label for multisig account creation
  ///
  /// In en, this message translates to:
  /// **'Multisig created'**
  String get activityTxMultisigCreated;

  /// Activity row label while multisig creation is confirming on-chain
  ///
  /// In en, this message translates to:
  /// **'Creating multisig'**
  String get activityTxMultisigCreating;

  /// Counterparty label for multisig creation row
  ///
  /// In en, this message translates to:
  /// **'Multisig'**
  String get activityTxMultisigLabel;

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

  /// Counterparty line of a private send whose proof was bundled with other transfers, so the chain cannot say who received it
  ///
  /// In en, this message translates to:
  /// **'Aggregated batch'**
  String get activityTxAggregatedBatch;

  /// Detail sheet 'To' value of a private send whose proof was bundled with other transfers
  ///
  /// In en, this message translates to:
  /// **'Aggregated batch, recipient not recorded'**
  String get activityDetailAggregatedBatch;

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

  /// Detail sheet title for pending encrypted send
  ///
  /// In en, this message translates to:
  /// **'Privately Sending'**
  String get activityDetailTitlePrivatelySending;

  /// Detail sheet title for pending encrypted receive
  ///
  /// In en, this message translates to:
  /// **'Privately Receiving'**
  String get activityDetailTitlePrivatelyReceiving;

  /// Detail sheet title for completed encrypted send
  ///
  /// In en, this message translates to:
  /// **'Private Sent'**
  String get activityDetailTitlePrivateSent;

  /// Detail sheet title for completed encrypted receive
  ///
  /// In en, this message translates to:
  /// **'Private Received'**
  String get activityDetailTitlePrivateReceived;

  /// Detail sheet title for multisig creation
  ///
  /// In en, this message translates to:
  /// **'Multisig created'**
  String get activityDetailTitleMultisigCreated;

  /// Detail sheet title while multisig creation is in progress
  ///
  /// In en, this message translates to:
  /// **'Creating multisig'**
  String get activityDetailTitleMultisigCreating;

  /// Detail sheet title for a confirmed multisig proposal creation
  ///
  /// In en, this message translates to:
  /// **'Proposal created'**
  String get activityDetailTitleProposalCreated;

  /// Detail sheet title for a confirmed multisig proposal approval
  ///
  /// In en, this message translates to:
  /// **'Proposal approved'**
  String get activityDetailTitleProposalApproved;

  /// Detail sheet title for a confirmed multisig proposal execution
  ///
  /// In en, this message translates to:
  /// **'Proposal executed'**
  String get activityDetailTitleProposalExecuted;

  /// Detail sheet title for a confirmed multisig proposal cancellation
  ///
  /// In en, this message translates to:
  /// **'Proposal cancelled'**
  String get activityDetailTitleProposalCancelled;

  /// Detail sheet title while a multisig proposal cancellation is confirming on-chain
  ///
  /// In en, this message translates to:
  /// **'Cancelling proposal'**
  String get activityDetailTitleCancelling;

  /// Detail sheet title while a multisig proposal execution is confirming on-chain
  ///
  /// In en, this message translates to:
  /// **'Executing proposal'**
  String get activityDetailTitleExecuting;

  /// Detail sheet title while a multisig proposal is confirming on-chain
  ///
  /// In en, this message translates to:
  /// **'Proposing'**
  String get activityDetailTitleProposing;

  /// Proposed transfer amount row label on proposal creation detail sheet
  ///
  /// In en, this message translates to:
  /// **'TRANSFER AMOUNT'**
  String get activityDetailProposalTransferAmount;

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

  /// Shown in place of the sender of a wormhole receipt, in the activity list and detail sheet
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get activitySenderEncrypted;

  /// Shown in place of the sender of a mining reward, in the activity list and detail sheet
  ///
  /// In en, this message translates to:
  /// **'Mining reward'**
  String get activitySenderMiningReward;

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

  /// Row in a private send's detail sheet, and title of the page listing its proof batches and nullifiers
  ///
  /// In en, this message translates to:
  /// **'Wormhole details'**
  String get activityDetailWormholeDetails;

  /// Heading of one proof extrinsic of a private send
  ///
  /// In en, this message translates to:
  /// **'Batch {index} of {count}'**
  String wormholeDetailsBatch(int index, int count);

  /// Amount one batch of a private send paid the recipient
  ///
  /// In en, this message translates to:
  /// **'SENT'**
  String get wormholeDetailsSent;

  /// Amount one batch of a private send returned to the wallet
  ///
  /// In en, this message translates to:
  /// **'CHANGE'**
  String get wormholeDetailsChange;

  /// Number of the wallet's leaves one batch consumed; each is listed by nullifier below
  ///
  /// In en, this message translates to:
  /// **'INPUTS'**
  String get wormholeDetailsInputs;

  /// Transaction hash row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'TX HASH'**
  String get activityDetailTxHash;

  /// Toast after copying a transaction hash from the activity detail sheet
  ///
  /// In en, this message translates to:
  /// **'Transaction hash copied to clipboard'**
  String get activityDetailTxHashCopied;

  /// Link to view transaction in explorer
  ///
  /// In en, this message translates to:
  /// **'View in Explorer ↗'**
  String get activityDetailViewExplorer;

  /// Multisig address row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'MULTISIG ADDRESS'**
  String get activityDetailMultisigAddress;

  /// Approval threshold row label on multisig detail sheet
  ///
  /// In en, this message translates to:
  /// **'THRESHOLD'**
  String get activityDetailMultisigThreshold;

  /// Approval threshold value on multisig detail sheet
  ///
  /// In en, this message translates to:
  /// **'{threshold} of {total}'**
  String activityDetailMultisigThresholdValue(int threshold, int total);

  /// Signer count row label on multisig detail sheet
  ///
  /// In en, this message translates to:
  /// **'SIGNERS'**
  String get activityDetailMultisigSignerCount;

  /// Creator account row label on multisig detail sheet
  ///
  /// In en, this message translates to:
  /// **'CREATOR'**
  String get activityDetailMultisigCreator;

  /// Multisig pallet fee row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'PALLET FEE'**
  String get activityDetailMultisigCreationFee;

  /// Multisig reserved deposit row label on detail sheet
  ///
  /// In en, this message translates to:
  /// **'RESERVED DEPOSIT'**
  String get activityDetailMultisigDeposit;

  /// Note when creation fee was paid by another account
  ///
  /// In en, this message translates to:
  /// **'Paid by creator'**
  String get activityDetailMultisigFeePaidByCreator;

  /// App bar title on receive screen
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

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

  /// Toast when the address is copied
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard'**
  String get receiveCopiedMessage;

  /// Label above the account address on the receive screen
  ///
  /// In en, this message translates to:
  /// **'YOUR ADDRESS'**
  String get receiveYourAddressLabel;

  /// Primary button that copies the receive address
  ///
  /// In en, this message translates to:
  /// **'Copy Address'**
  String get receiveCopyAddress;

  /// Footnote under the checkphrase on the receive screen
  ///
  /// In en, this message translates to:
  /// **'Ask the sender to confirm this phrase matches your address.'**
  String get receiveCheckphraseFootnote;

  /// App bar title on settings hub
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Wallet row title on settings hub
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get settingsWalletTitle;

  /// Wallet row subtitle on settings hub
  ///
  /// In en, this message translates to:
  /// **'Recovery Phrase, Reset Wallet'**
  String get settingsWalletSubtitle;

  /// Preferences row title on settings hub
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesTitle;

  /// Preferences row subtitle on settings hub
  ///
  /// In en, this message translates to:
  /// **'Language, currency, notifications'**
  String get settingsPreferencesSubtitle;

  /// Add account row title on settings hub
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get settingsAccountTypeTitle;

  /// Add account row subtitle on settings hub
  ///
  /// In en, this message translates to:
  /// **'Manage your accounts'**
  String get settingsAccountTypeSubtitle;

  /// Help row title on settings hub
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsHelpTitle;

  /// Help row subtitle on settings hub
  ///
  /// In en, this message translates to:
  /// **'FAQs, Contact the team'**
  String get settingsHelpSubtitle;

  /// About row title on settings hub
  ///
  /// In en, this message translates to:
  /// **'About Quantus'**
  String get settingsAboutTitle;

  /// About row subtitle on settings hub
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String settingsAboutHubSubtitle(String version, String build);

  /// Recovery phrase row on wallet settings
  ///
  /// In en, this message translates to:
  /// **'Recovery Phrase'**
  String get settingsWalletRecoveryPhrase;

  /// Recovery phrase row subtitle
  ///
  /// In en, this message translates to:
  /// **'View your 24-word Backup Password'**
  String get settingsWalletRecoveryPhraseSubtitle;

  /// Reset wallet row title
  ///
  /// In en, this message translates to:
  /// **'Reset Wallet'**
  String get settingsWalletReset;

  /// Reset wallet row subtitle
  ///
  /// In en, this message translates to:
  /// **'Removes all data from this device'**
  String get settingsWalletResetSubtitle;

  /// Error when no wallets exist
  ///
  /// In en, this message translates to:
  /// **'No wallets found'**
  String get settingsWalletNoWalletsFound;

  /// Error when wallet list fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load wallets'**
  String get settingsWalletFailedToLoad;

  /// App bar on select wallet screen
  ///
  /// In en, this message translates to:
  /// **'Select Wallet'**
  String get settingsSelectWalletTitle;

  /// Empty state on select wallet screen
  ///
  /// In en, this message translates to:
  /// **'No wallets found'**
  String get settingsSelectWalletNoWallets;

  /// Wallet list item label on select wallet screen
  ///
  /// In en, this message translates to:
  /// **'Wallet {number}'**
  String settingsSelectWalletItem(int number);

  /// Biometric prompt when viewing recovery phrase
  ///
  /// In en, this message translates to:
  /// **'Authenticate to see recovery phrase'**
  String get settingsRecoveryConfirmAuthReason;

  /// Toaster when auth fails for recovery phrase
  ///
  /// In en, this message translates to:
  /// **'Authentication required to see recovery phrase'**
  String get settingsRecoveryConfirmAuthRequired;

  /// App bar on recovery phrase screen
  ///
  /// In en, this message translates to:
  /// **'Recovery Phrase'**
  String get settingsRecoveryPhraseTitle;

  /// Done button on recovery phrase screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsRecoveryPhraseDone;

  /// Secondary action on the recovery phrase caution screen that dismisses the backup reminder without revealing the phrase
  ///
  /// In en, this message translates to:
  /// **'I already backed up my wallet'**
  String get settingsRecoveryAlreadyBackedUp;

  /// App bar on reset wallet caution screen
  ///
  /// In en, this message translates to:
  /// **'Reset Wallet'**
  String get settingsResetTitle;

  /// Biometric prompt when resetting wallet
  ///
  /// In en, this message translates to:
  /// **'Authenticate to reset wallet'**
  String get settingsResetAuthReason;

  /// Toaster when wallet reset fails
  ///
  /// In en, this message translates to:
  /// **'Failed to reset wallet: {error}'**
  String settingsResetFailed(String error);

  /// Toaster when auth fails for wallet reset
  ///
  /// In en, this message translates to:
  /// **'Authentication required to reset wallet'**
  String get settingsResetAuthRequired;

  /// Headline on wallet reset caution screen
  ///
  /// In en, this message translates to:
  /// **'This will erase\nyour wallet'**
  String get settingsResetCautionHeadline;

  /// First bullet on wallet reset caution
  ///
  /// In en, this message translates to:
  /// **'All wallet data will be permanently removed from this device'**
  String get settingsResetCautionBullet1;

  /// Second bullet on wallet reset caution
  ///
  /// In en, this message translates to:
  /// **'Your funds stay on the blockchain but only your recovery phrase can restore access'**
  String get settingsResetCautionBullet2;

  /// Third bullet on wallet reset caution
  ///
  /// In en, this message translates to:
  /// **'Without it, your funds are gone forever'**
  String get settingsResetCautionBullet3;

  /// Checkbox label on wallet reset caution
  ///
  /// In en, this message translates to:
  /// **'I\'ve backed up my recovery phrase'**
  String get settingsResetCautionCheckbox;

  /// Currency row on preferences screen
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsPreferencesCurrency;

  /// Currency row subtitle
  ///
  /// In en, this message translates to:
  /// **'Fiat display preference'**
  String get settingsPreferencesCurrencySubtitle;

  /// Language row on preferences screen
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsPreferencesLanguage;

  /// Language row subtitle
  ///
  /// In en, this message translates to:
  /// **'App display language'**
  String get settingsPreferencesLanguageSubtitle;

  /// Notifications row on preferences
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsPreferencesNotifications;

  /// Notifications row subtitle
  ///
  /// In en, this message translates to:
  /// **'Transaction and wallet alerts'**
  String get settingsPreferencesNotificationsSubtitle;

  /// App bar on currency picker
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrencyTitle;

  /// Search field hint on currency picker
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settingsCurrencySearchHint;

  /// Empty state when search has no results
  ///
  /// In en, this message translates to:
  /// **'No currencies match your search'**
  String get settingsCurrencyNoMatch;

  /// Error when currency selection fails
  ///
  /// In en, this message translates to:
  /// **'Error selecting currency: {error}'**
  String settingsCurrencyError(String error);

  /// App bar on language picker
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Search field hint on language picker
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get settingsLanguageSearchHint;

  /// Empty state when language search has no results
  ///
  /// In en, this message translates to:
  /// **'No languages match your search'**
  String get settingsLanguageNoMatch;

  /// Error when language selection fails
  ///
  /// In en, this message translates to:
  /// **'Error selecting language: {error}'**
  String settingsLanguageError(String error);

  /// App bar on help and support screen
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsHelpScreenTitle;

  /// Telegram row title
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get settingsHelpTelegram;

  /// App bar on about screen
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutScreenTitle;

  /// Intro paragraph on about screen
  ///
  /// In en, this message translates to:
  /// **'Quantus is a Layer 1 blockchain secured by ML-DSA Dilithium-5, the gold standard in quantum-resistant encryption. Built for a future where classical cryptography is no longer enough. Post-quantum cryptography for everyone.'**
  String get settingsAboutIntro;

  /// Terms of service link title
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsAboutTerms;

  /// Terms of service link subtitle
  ///
  /// In en, this message translates to:
  /// **'quantus.com/terms/'**
  String get settingsAboutTermsSubtitle;

  /// Privacy policy link title
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsAboutPrivacy;

  /// Privacy policy link subtitle
  ///
  /// In en, this message translates to:
  /// **'quantus.com/privacy-policy/'**
  String get settingsAboutPrivacySubtitle;

  /// Website link title
  ///
  /// In en, this message translates to:
  /// **'Visit Website'**
  String get settingsAboutWebsite;

  /// Website link subtitle
  ///
  /// In en, this message translates to:
  /// **'quantus.com'**
  String get settingsAboutWebsiteSubtitle;

  /// Version label on about screen
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String settingsAboutVersion(String version, String build);

  /// App bar title on swap screens
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swapTitle;

  /// Label above the NEAR Intents logo in the swap app bar
  ///
  /// In en, this message translates to:
  /// **'Powered By'**
  String get swapPoweredBy;

  /// Label of the side the swapped funds come from
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get swapFrom;

  /// Label of the side the swapped funds go to
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get swapTo;

  /// Owner of the external token side of the swap form
  ///
  /// In en, this message translates to:
  /// **'A wallet you control'**
  String get swapExternalWallet;

  /// Exchange rate label on swap screen
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get swapRate;

  /// Exchange rate: what one input token buys
  ///
  /// In en, this message translates to:
  /// **'1 {fromSymbol} = {rate} {toSymbol}'**
  String swapRateLabel(String fromSymbol, String rate, String toSymbol);

  /// Exchange rate at listed prices, shown on the swap form until a quote arrives
  ///
  /// In en, this message translates to:
  /// **'1 {fromSymbol} ≈ {rate} {toSymbol}'**
  String swapRateEstimateLabel(String fromSymbol, String rate, String toSymbol);

  /// Under the swap form's rate while its figures are not a quote yet
  ///
  /// In en, this message translates to:
  /// **'Estimate at the market price, before fees.'**
  String get swapEstimateNotice;

  /// Slippage tolerance under the swap form
  ///
  /// In en, this message translates to:
  /// **'Slippage {percent}%'**
  String swapSlippageLabel(String percent);

  /// Title of the slippage tolerance sheet
  ///
  /// In en, this message translates to:
  /// **'Slippage'**
  String get swapSlippageTitle;

  /// Explanation on the slippage tolerance sheet
  ///
  /// In en, this message translates to:
  /// **'If the price moves further than this before your swap fills, it is refunded instead. A higher tolerance fills more often but can pay out less.'**
  String get swapSlippageBody;

  /// Slippage tolerance option that opens a field for any tolerance
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get swapSlippageCustom;

  /// Error under the custom slippage field when the tolerance is too high
  ///
  /// In en, this message translates to:
  /// **'Slippage can be at most {percent}%'**
  String swapSlippageCustomMax(String percent);

  /// Swap form button for a swap out of QTC
  ///
  /// In en, this message translates to:
  /// **'Add Recipient Address'**
  String get swapAddRecipientAddress;

  /// Swap form button for a swap into QTC
  ///
  /// In en, this message translates to:
  /// **'Add Refund Address'**
  String get swapAddRefundAddress;

  /// Label of the swap form row holding the refund address of a swap into QTC
  ///
  /// In en, this message translates to:
  /// **'Refund to'**
  String get swapRefundTo;

  /// Title of the token picker for the side that pays
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get swapTokenPickerPayWith;

  /// Title of the token picker for the side that receives
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get swapTokenPickerReceive;

  /// Error when token list fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load tokens'**
  String get swapTokenPickerLoadError;

  /// Search field hint on token picker sheet
  ///
  /// In en, this message translates to:
  /// **'Search token or chain'**
  String get swapTokenPickerSearchHint;

  /// Empty state when the token picker search matches nothing
  ///
  /// In en, this message translates to:
  /// **'No tokens match your search'**
  String get swapTokenPickerNoMatch;

  /// Title of the notice that replaces the swap form while swaps cannot be made
  ///
  /// In en, this message translates to:
  /// **'Swap unavailable'**
  String get swapUnavailableTitle;

  /// Notice that replaces the swap form while NEAR Intents does not list QTC with a price; says nothing about why or when
  ///
  /// In en, this message translates to:
  /// **'Swap disabled'**
  String get swapDisabledTitle;

  /// Body of the swap unavailable notice when the 1Click token list fails to load; shown with a retry
  ///
  /// In en, this message translates to:
  /// **'NEAR Intents could not be reached.'**
  String get swapUnavailableUnreachable;

  /// Toast when the configured QTC asset changed while a swap was being confirmed; the confirmation stops
  ///
  /// In en, this message translates to:
  /// **'The swap\'s terms changed. Review it again.'**
  String get swapReviewListingChanged;

  /// Banner on the swap form in the debug-only preflight mode, naming the listed token standing in for QTC
  ///
  /// In en, this message translates to:
  /// **'Preflight: {symbol} on {network} stands in for QTC. Real funds move.'**
  String swapPreflightBanner(String symbol, String network);

  /// Toast when 1Click rejects a quote or a swap cannot be created
  ///
  /// In en, this message translates to:
  /// **'Quote failed: {message}'**
  String swapQuoteError(String message);

  /// Title of the sheet asking where the swapped funds go
  ///
  /// In en, this message translates to:
  /// **'Recipient Address'**
  String get swapRecipientAddressTitle;

  /// Title of the sheet asking where a failed swap is refunded
  ///
  /// In en, this message translates to:
  /// **'Refund Address'**
  String get swapRefundAddressTitle;

  /// Address field label in the swap address sheet
  ///
  /// In en, this message translates to:
  /// **'{symbol} Address'**
  String swapAddressLabel(String symbol);

  /// Address field hint in the swap address sheet
  ///
  /// In en, this message translates to:
  /// **'{network} Address'**
  String swapAddressHint(String network);

  /// Warning under the recipient address field
  ///
  /// In en, this message translates to:
  /// **'Your {symbol} will arrive at this address. Double-check it, swaps cannot be reversed.'**
  String swapRecipientAddressNotice(String symbol);

  /// Warning under the refund address field
  ///
  /// In en, this message translates to:
  /// **'If the swap cannot complete, your {symbol} returns to this address on {network}. Double-check it.'**
  String swapRefundAddressNotice(String symbol, String network);

  /// Checkbox that saves the entered address
  ///
  /// In en, this message translates to:
  /// **'Save for future swaps'**
  String get swapSaveAddress;

  /// Button that quotes the swap with the entered address
  ///
  /// In en, this message translates to:
  /// **'Continue to Swap'**
  String get swapContinue;

  /// Title of the saved swap addresses sheet
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get swapSavedAddressesTitle;

  /// Empty saved swap addresses sheet
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet'**
  String get swapSavedAddressesEmpty;

  /// Title of the swap review screen
  ///
  /// In en, this message translates to:
  /// **'Review Swap'**
  String get swapReviewTitle;

  /// Pay side of the swap review card
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get swapYouPay;

  /// Receive side of the swap review card
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get swapYouReceive;

  /// Review row: external address receiving the swap
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get swapReviewRecipient;

  /// Review row and details row: chain fee of the QTC deposit
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get swapReviewNetworkFee;

  /// Network fee value when it could not be fetched
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get swapReviewFeeUnavailable;

  /// Error under the review rows when the fee failed
  ///
  /// In en, this message translates to:
  /// **'Could not get the network fee.'**
  String get swapReviewFeeFailed;

  /// Review row: how far below the quote the output may land
  ///
  /// In en, this message translates to:
  /// **'Slippage allowance'**
  String get swapReviewSlippage;

  /// An amount with the percentage it is: the slippage allowance, the swap fee
  ///
  /// In en, this message translates to:
  /// **'{amount} ({percent}%)'**
  String swapReviewSlippageValue(String amount, String percent);

  /// Review row: least the swap pays out
  ///
  /// In en, this message translates to:
  /// **'Guaranteed minimum'**
  String get swapReviewGuaranteedMinimum;

  /// Swap form and review row: percentage fee taken from the payment
  ///
  /// In en, this message translates to:
  /// **'Swap fee'**
  String get swapReviewSwapFee;

  /// Swap form and review row: fixed fee for paying the swap out on the recipient's chain
  ///
  /// In en, this message translates to:
  /// **'Withdrawal fee'**
  String get swapReviewWithdrawalFee;

  /// Review row: fixed fee taken from the payment when the swap fails and is refunded
  ///
  /// In en, this message translates to:
  /// **'Fee if refunded'**
  String get swapReviewRefundFee;

  /// Review note on a swap for an exact amount out, whose payment holds a refundable buffer
  ///
  /// In en, this message translates to:
  /// **'The payment includes the slippage allowance. Whatever the swap does not use is refunded.'**
  String get swapReviewUnusedRefunded;

  /// Review error when the balance cannot cover the deposit
  ///
  /// In en, this message translates to:
  /// **'Not enough {symbol} for this amount plus the network fee.'**
  String swapReviewInsufficient(String symbol);

  /// Toast when the live quote guarantees less than the one reviewed
  ///
  /// In en, this message translates to:
  /// **'The price moved. Check the new amounts and confirm again.'**
  String get swapReviewPriceMoved;

  /// Confirm button on the swap review screen
  ///
  /// In en, this message translates to:
  /// **'Confirm swap'**
  String get swapReviewConfirm;

  /// Home activity row state for a followed swap that is overdue
  ///
  /// In en, this message translates to:
  /// **'Not finished in time'**
  String get swapActivityOverdue;

  /// Toast on Review Swap when as many swaps as can be followed are already running
  ///
  /// In en, this message translates to:
  /// **'Up to {count} swaps can run at once. Wait for one to finish.'**
  String swapTooManyFollowed(int count);

  /// Title of the home activity row for the swap with 1Click; the step it is on is the subtitle
  ///
  /// In en, this message translates to:
  /// **'{amountIn} → {amountOut}'**
  String swapActivityAmounts(String amountIn, String amountOut);

  /// Title while the swap is running
  ///
  /// In en, this message translates to:
  /// **'Swap In Progress'**
  String get swapInProgressTitle;

  /// Pay side of the swap progress card
  ///
  /// In en, this message translates to:
  /// **'You\'re paying'**
  String get swapYourePaying;

  /// Receive side of the swap progress card
  ///
  /// In en, this message translates to:
  /// **'You\'re receiving'**
  String get swapYoureReceiving;

  /// First swap progress step when the user deposits from another wallet
  ///
  /// In en, this message translates to:
  /// **'{symbol} deposited'**
  String swapStepDeposited(String symbol);

  /// Progress step: deposit sent
  ///
  /// In en, this message translates to:
  /// **'{symbol} sent'**
  String swapStepSent(String symbol);

  /// Progress step: deposit confirming
  ///
  /// In en, this message translates to:
  /// **'Confirming on {network}'**
  String swapStepConfirming(String network);

  /// Progress step: solvers swapping
  ///
  /// In en, this message translates to:
  /// **'Swapping'**
  String get swapStepSwapping;

  /// Progress step: payout
  ///
  /// In en, this message translates to:
  /// **'Sending {symbol} to {recipient}'**
  String swapStepSending(String symbol, String recipient);

  /// Footer under the swap progress bar
  ///
  /// In en, this message translates to:
  /// **'Usually a few minutes. You can leave the app, the swap carries on. · via NEAR Intents'**
  String get swapProgressFooter;

  /// Lock screen header while a swap is underway or complete
  ///
  /// In en, this message translates to:
  /// **'Swapping'**
  String get swapLiveBrand;

  /// Lock screen header when the swap card is stale or failed
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swapLiveBrandIdle;

  /// Lock screen headline after the deposit is sent
  ///
  /// In en, this message translates to:
  /// **'Swap submitted'**
  String get swapLiveSubmitted;

  /// Lock screen headline while the swap pays out on the destination chain
  ///
  /// In en, this message translates to:
  /// **'Settling on {network}'**
  String swapLiveSettling(String network);

  /// Lock screen headline when the swap has paid out
  ///
  /// In en, this message translates to:
  /// **'Swapped'**
  String get swapLiveSwapped;

  /// Lock screen label for the amount paid
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get swapLiveFrom;

  /// Lock screen label for the amount received
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get swapLiveTo;

  /// Lock screen label for the source chain
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get swapLiveChain;

  /// Lock screen footer when the swap card could not be updated
  ///
  /// In en, this message translates to:
  /// **'Open Quantus to check'**
  String get swapLiveOpenToCheck;

  /// Lock screen suffix after how long the card has been stale
  ///
  /// In en, this message translates to:
  /// **'ago'**
  String get swapLiveAgo;

  /// Lock screen suffix after the remaining swap time, as in 5 min left
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get swapLiveLeft;

  /// Lock screen unit for a remaining swap time under an hour
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get swapLiveMinute;

  /// Lock screen unit for a remaining swap time of an hour or more
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get swapLiveHour;

  /// Lock screen badge once a swap has run past 1Click's time estimate
  ///
  /// In en, this message translates to:
  /// **'Taking longer'**
  String get swapLiveOverdue;

  /// Android notification channel for the swap lock screen card
  ///
  /// In en, this message translates to:
  /// **'Swap progress'**
  String get swapLiveChannel;

  /// Title of the swap details sheet
  ///
  /// In en, this message translates to:
  /// **'Swap Details'**
  String get swapDetailsTitle;

  /// Details row: address receiving the swap
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get swapDetailsRecipient;

  /// Details row: deposit amount
  ///
  /// In en, this message translates to:
  /// **'Amount sent'**
  String get swapDetailsAmountSent;

  /// Details row: quoted payout
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get swapDetailsExpected;

  /// Swap details row: where a swap into QTC was to be deposited
  ///
  /// In en, this message translates to:
  /// **'Deposit address'**
  String get swapDetailsDepositAddress;

  /// Swap details row: the amount a swap into QTC needed deposited
  ///
  /// In en, this message translates to:
  /// **'Required deposit'**
  String get swapDetailsRequiredDeposit;

  /// Swap details row: when the deposit address of a swap into QTC expires
  ///
  /// In en, this message translates to:
  /// **'Deposit window ends'**
  String get swapDetailsDepositWindowEnds;

  /// Title of the screen showing where to send the deposit of a swap into QTC
  ///
  /// In en, this message translates to:
  /// **'Send Your Deposit'**
  String get swapDepositTitle;

  /// Button on the deposit screen once the user has sent the deposit
  ///
  /// In en, this message translates to:
  /// **'I\'ve Sent It'**
  String get swapDepositSent;

  /// Details row: deposit transaction hash
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get swapDetailsTransaction;

  /// Title when the swap paid out
  ///
  /// In en, this message translates to:
  /// **'Swap Complete'**
  String get swapCompleteTitle;

  /// Caption under the paid-out amount
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get swapCompleteReceived;

  /// Label above where the swap paid out
  ///
  /// In en, this message translates to:
  /// **'To:'**
  String get swapCompleteTo;

  /// Title when the swap did not pay out
  ///
  /// In en, this message translates to:
  /// **'Swap Failed'**
  String get swapFailedTitle;

  /// Status label on a refunded swap
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get swapRefundedLabel;

  /// Pay side of a failed swap card
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get swapYouPaid;

  /// Receive side of a failed swap card
  ///
  /// In en, this message translates to:
  /// **'You were receiving'**
  String get swapYouWereReceiving;

  /// Banner on a refunded swap
  ///
  /// In en, this message translates to:
  /// **'The swap could not be completed, so your {amount} has been returned to {destination}, minus the network fee. The {symbol} was never sent.'**
  String swapRefundedBody(String amount, String destination, String symbol);

  /// Refund reason reported by 1Click
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String swapDepositRefundReason(String reason);

  /// Body when 1Click reports the swap failed
  ///
  /// In en, this message translates to:
  /// **'The swap did not complete. Contact support and quote this deposit address: {address}'**
  String swapDepositFailedBody(String address);

  /// Title when less than the quoted amount arrived
  ///
  /// In en, this message translates to:
  /// **'Deposit Too Small'**
  String get swapDepositIncompleteTitle;

  /// Body when less than the quoted amount arrived
  ///
  /// In en, this message translates to:
  /// **'Less than the quoted amount arrived. It will be refunded to your refund address after the deadline.'**
  String get swapDepositIncompleteBody;

  /// Title when the deadline passed with no deposit
  ///
  /// In en, this message translates to:
  /// **'Quote Expired'**
  String get swapDepositExpiredTitle;

  /// Body when the deadline passed with no deposit
  ///
  /// In en, this message translates to:
  /// **'No deposit arrived before the deadline. Do not send funds to this address anymore. Get a new quote to try again.'**
  String get swapDepositExpiredBody;

  /// Button on a failed swap
  ///
  /// In en, this message translates to:
  /// **'Start a New Swap'**
  String get swapStartNew;

  /// Toast when the deposit address is copied
  ///
  /// In en, this message translates to:
  /// **'Deposit address copied to clipboard'**
  String get swapDepositAddressCopied;

  /// Under the deposit card; the symbol and the network are emphasised
  ///
  /// In en, this message translates to:
  /// **'Send {symbol} on {network} only'**
  String swapDepositOnly(String symbol, String network);

  /// Local time by which the deposit must arrive
  ///
  /// In en, this message translates to:
  /// **'Send before {time} or the quote expires'**
  String swapDepositDeadline(String time);

  /// Label of the deposit memo some chains require
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get swapDepositMemo;

  /// Toast when the deposit memo is copied
  ///
  /// In en, this message translates to:
  /// **'Deposit memo copied to clipboard'**
  String get swapDepositMemoCopied;

  /// Warning under a deposit memo
  ///
  /// In en, this message translates to:
  /// **'Include this memo with your deposit. A deposit without it is not processed.'**
  String get swapDepositMemoNotice;

  /// Why a 1Click request failed when no answer came within the time allowed
  ///
  /// In en, this message translates to:
  /// **'The request timed out'**
  String get swapRequestTimedOut;

  /// Notice on the progress screen while the 1Click status poll fails
  ///
  /// In en, this message translates to:
  /// **'The swap status can\'t be checked right now: {error}'**
  String swapProgressStatusUnavailable(String error);

  /// Puts a running swap away: in its details sheet, and under its notice once it is overdue
  ///
  /// In en, this message translates to:
  /// **'Stop tracking swap'**
  String get swapStopTracking;

  /// Confirm sheet title before a running swap is put away
  ///
  /// In en, this message translates to:
  /// **'Stop tracking this swap?'**
  String get swapStopTrackingConfirmTitle;

  /// Confirm sheet body before a running swap is put away
  ///
  /// In en, this message translates to:
  /// **'It carries on at NEAR Intents: the funds still arrive, or the deposit is refunded. The wallet just stops following it.'**
  String get swapStopTrackingConfirmBody;

  /// Notice on the progress screen once the deposit window closed with the deposit unseen
  ///
  /// In en, this message translates to:
  /// **'This swap has not finished in time. If it settles later, the funds still arrive, or the deposit is refunded to {refund}.'**
  String swapProgressOverdue(String refund);

  /// Label next to the back caret on the QR scanner
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get componentQrScannerBack;

  /// Label under the torch control on the QR scanner
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get componentQrScannerTorch;

  /// Label under the control that picks a QR image from the gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get componentQrScannerGallery;

  /// Shown in the scan window when the camera could not be started
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get componentQrScannerCameraUnavailable;

  /// Shown in the scan window when camera permission was denied
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Settings to scan.'**
  String get componentQrScannerCameraDenied;

  /// Snackbar when gallery image has no QR code
  ///
  /// In en, this message translates to:
  /// **'No QR code found in image'**
  String get componentQrScannerNoCode;

  /// Share button label on account screens
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get componentShare;

  /// Address field label on address details card
  ///
  /// In en, this message translates to:
  /// **'ADDRESS'**
  String get componentAddressLabel;

  /// Checkphrase field label on address details card
  ///
  /// In en, this message translates to:
  /// **'CHECKPHRASE'**
  String get componentCheckphraseLabel;

  /// Toast when checkphrase is copied
  ///
  /// In en, this message translates to:
  /// **'Checkphrase copied'**
  String get componentCheckphraseCopied;

  /// Hint text on account name field
  ///
  /// In en, this message translates to:
  /// **'Enter a name for your account'**
  String get componentNameFieldHint;

  /// Prefix before a converted secondary amount
  ///
  /// In en, this message translates to:
  /// **'≈'**
  String get componentAmountApproximatePrefix;

  /// Text for generic loading state
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// Generic cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Text shown while a cancellation is in progress
  ///
  /// In en, this message translates to:
  /// **'Canceling...'**
  String get commonCanceling;

  /// Formatted balance with token symbol
  ///
  /// In en, this message translates to:
  /// **'{balance} {symbol}'**
  String commonAmountBalance(String balance, String symbol);

  /// Continue button on various screens
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Done button on various screens
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Button that closes a sheet or dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Button that returns to the previous page
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Save button on sheets that apply a pick
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// A percentage, as a slippage option or a share of the balance
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String commonPercent(String percent);

  /// Link to support from a failed swap or the Keystone mismatch screen
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get commonContactSupport;

  /// Retry action on various screens
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Retry label shown when a list or quote fails to load
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// Cancel button on redeem progress
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get redeemCancel;

  /// Close button on redeem progress
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get redeemClose;

  /// Fee label for encrypted sends (wormhole volume fee)
  ///
  /// In en, this message translates to:
  /// **'Transaction Fee'**
  String get encryptedSendFeeLabel;

  /// Shown when an encrypted send amount is not a multiple of 0.01 token
  ///
  /// In en, this message translates to:
  /// **'Use steps of 0.01 {tokenSymbol}'**
  String encryptedSendAmountStep(String tokenSymbol);

  /// Button label when an encrypted send exceeds the spendable balance while change from an earlier send is still pending
  ///
  /// In en, this message translates to:
  /// **'Insufficient Balance ({amount} {tokenSymbol} pending)'**
  String encryptedSendInsufficientWithPending(String amount, String tokenSymbol);

  /// Shown when an encrypted send falls below the chain's minimum exit amount
  ///
  /// In en, this message translates to:
  /// **'Encrypted sends must move at least 0.1 {tokenSymbol}'**
  String encryptedSendMinimum(String tokenSymbol);

  /// App bar title while an encrypted send is proving/submitting
  ///
  /// In en, this message translates to:
  /// **'Private Send'**
  String get encryptedSendProgressTitle;

  /// App bar title when an encrypted send failed
  ///
  /// In en, this message translates to:
  /// **'Send Failed'**
  String get encryptedSendFailedTitle;

  /// App bar title when an encrypted send was cancelled
  ///
  /// In en, this message translates to:
  /// **'Send Cancelled'**
  String get encryptedSendCancelledTitle;

  /// Status header label on encrypted send progress
  ///
  /// In en, this message translates to:
  /// **'SENDING PRIVATELY'**
  String get encryptedSendingLabel;

  /// Encrypted send progress step: preparing circuits
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get encryptedSendStepPreparing;

  /// Encrypted send progress step: fetching on-chain state for the batch
  ///
  /// In en, this message translates to:
  /// **'Gathering funds'**
  String get encryptedSendStepGathering;

  /// Encrypted send progress step: computing and checking nullifiers
  ///
  /// In en, this message translates to:
  /// **'Securing transaction'**
  String get encryptedSendStepSecuring;

  /// Encrypted send progress step: generating individual ZK proofs
  ///
  /// In en, this message translates to:
  /// **'Generate proofs'**
  String get encryptedSendStepGenerating;

  /// Encrypted send progress step: aggregating ZK proofs
  ///
  /// In en, this message translates to:
  /// **'Building privacy proof'**
  String get encryptedSendStepProving;

  /// Encrypted send progress step: submitting the transaction
  ///
  /// In en, this message translates to:
  /// **'Submitting to chain'**
  String get encryptedSendStepSubmitting;

  /// Footer text on encrypted send progress screen
  ///
  /// In en, this message translates to:
  /// **'Privacy takes a moment. Please keep the app open until the transaction completes.'**
  String get encryptedSendProgressFooter;

  /// Notice on the cancelled encrypted-send screen when some batches were already submitted
  ///
  /// In en, this message translates to:
  /// **'{amount} was already sent before cancelling. The rest remains in your account.'**
  String encryptedSendCancelledPartial(String amount);

  /// Stacked banner kicker when an encrypted send was cancelled before anything left the wallet
  ///
  /// In en, this message translates to:
  /// **'Your funds are safe'**
  String get encryptedSendFundsSafeLabel;

  /// Stacked banner caption when an encrypted send was cancelled before anything left the wallet
  ///
  /// In en, this message translates to:
  /// **'Still in {account}. Nothing left your wallet.'**
  String encryptedSendFundsSafeCaption(String account);

  /// Title of the private-send notice on encrypted send recipient screen
  ///
  /// In en, this message translates to:
  /// **'Private Send'**
  String get privateSendTitle;

  /// Subtitle of the private-send notice on encrypted send recipient screen. Must not overstate the guarantee: the recipient and amount are still visible on chain, only the source linkage is hidden.
  ///
  /// In en, this message translates to:
  /// **'Hides the link between your account and the recipient'**
  String get privateSendSubtitle;

  /// Title of the warning on the encrypted send recipient screen when the address is a 1Click (NEAR Intents) swap deposit address
  ///
  /// In en, this message translates to:
  /// **'NEAR Intents address detected'**
  String get encryptedSendNearIntentsTitle;

  /// Body of that warning: encrypted sends to 1Click deposit addresses are refused because each address takes exactly one deposit
  ///
  /// In en, this message translates to:
  /// **'This is a single-use NEAR Intents deposit address. Use a transparent account to send to NEAR Intents.'**
  String get encryptedSendNearIntentsDescription;

  /// Disabled continue button label while the recipient is a NEAR Intents deposit address
  ///
  /// In en, this message translates to:
  /// **'Can\'t Send to NEAR Intents'**
  String get encryptedSendNearIntentsButton;

  /// Disabled continue button label while the recipient check (self-send, NEAR Intents) is in flight
  ///
  /// In en, this message translates to:
  /// **'Verifying Address…'**
  String get sendRecipientChecking;

  /// Disabled continue button label when the recipient's self-send check failed; entering the address again retries it
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t Verify Address'**
  String get sendRecipientCheckFailed;

  /// Toast on the recipient screen, and error at confirm, when the NEAR Intents lookup failed, e.g. offline
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify the address. Check your connection and try again.'**
  String get sendRecipientCheckFailedMessage;

  /// Error shown when the planned inputs of an encrypted send were spent between review and confirm
  ///
  /// In en, this message translates to:
  /// **'Your encrypted balance changed while reviewing. Please go back and enter the amount again.'**
  String get encryptedSendPlanStale;

  /// Headline of the mainnet migration checking page; the part between asterisks is highlighted
  ///
  /// In en, this message translates to:
  /// **'Quantus is live on *mainnet*.'**
  String get mainnetMigrationTitle;

  /// Body of the checking page
  ///
  /// In en, this message translates to:
  /// **'Testnet has shut down. Checking what that means for this wallet.'**
  String get mainnetMigrationChecking;

  /// Progress label on the checking page, shown uppercase
  ///
  /// In en, this message translates to:
  /// **'Reading testnet history'**
  String get mainnetMigrationReadingHistory;

  /// Formatted number of testnet blocks mined
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String mainnetMigrationBlocksMinedCount(int count);

  /// Label under the blocks-mined number, shown uppercase
  ///
  /// In en, this message translates to:
  /// **'Blocks mined on testnet'**
  String get mainnetMigrationBlocksMined;

  /// Title for wallets that mined testnet blocks
  ///
  /// In en, this message translates to:
  /// **'Keep this wallet.'**
  String get mainnetMigrationMinerTitle;

  /// Body for wallets that mined testnet blocks
  ///
  /// In en, this message translates to:
  /// **'Your rewards are safe. They\'re tied to it and arrive after launch. Your balance starts at zero because rewards are based on blocks mined, not on your testnet balance.'**
  String get mainnetMigrationMinerBody;

  /// Title for wallets that did not mine
  ///
  /// In en, this message translates to:
  /// **'Nothing carried over.'**
  String get mainnetMigrationNotMinedTitle;

  /// Body for wallets that did not mine
  ///
  /// In en, this message translates to:
  /// **'Your testnet balance stayed on testnet. Those coins were only ever for testing, so this wallet starts at zero {tokenSymbol}.'**
  String mainnetMigrationNotMinedBody(String tokenSymbol);

  /// Badge on the page shown when the testnet check fails, shown uppercase
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check'**
  String get mainnetMigrationUnreachableBadge;

  /// Title when the testnet check fails
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check this wallet.'**
  String get mainnetMigrationUnreachableTitle;

  /// Body when the testnet check fails
  ///
  /// In en, this message translates to:
  /// **'Testnet was unreachable, so we don\'t know yet whether you mined. Your balance starts at zero {tokenSymbol} either way.'**
  String mainnetMigrationUnreachableBody(String tokenSymbol);

  /// Reassurance when the testnet check fails
  ///
  /// In en, this message translates to:
  /// **'If you mined, your rewards are safe. They stay tied to this wallet whether we can check today or not.'**
  String get mainnetMigrationUnreachableRewards;

  /// Button that keeps the existing wallet
  ///
  /// In en, this message translates to:
  /// **'Keep this wallet'**
  String get mainnetMigrationKeepWallet;

  /// Button that offers a fresh wallet next to the existing one
  ///
  /// In en, this message translates to:
  /// **'Create a new wallet'**
  String get mainnetMigrationCreateWallet;

  /// Title of the confirmation before creating a new wallet
  ///
  /// In en, this message translates to:
  /// **'Create a new wallet?'**
  String get mainnetMigrationCreateDialogTitle;

  /// Body of the confirmation before creating a new wallet
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a new secret phrase to write down and store safely. This wallet stays on the device.'**
  String get mainnetMigrationCreateDialogBody;

  /// Banner title in the confirmation when the testnet check failed
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check this wallet'**
  String get mainnetMigrationCreateDialogUncheckedTitle;

  /// Banner body in the confirmation when the testnet check failed
  ///
  /// In en, this message translates to:
  /// **'So we don\'t know whether you mined on testnet.'**
  String get mainnetMigrationCreateDialogUncheckedBody;

  /// Body of the confirmation when the testnet check failed
  ///
  /// In en, this message translates to:
  /// **'If you mined, your rewards are tied to this wallet. We\'d suggest keeping it and trying again later.'**
  String get mainnetMigrationCreateDialogUncheckedAdvice;

  /// Confirmation button that creates the new wallet
  ///
  /// In en, this message translates to:
  /// **'Create new wallet'**
  String get mainnetMigrationCreateDialogConfirm;

  /// Confirmation button that keeps the existing wallet
  ///
  /// In en, this message translates to:
  /// **'Keep my wallet'**
  String get mainnetMigrationCreateDialogCancel;

  /// Badge on the closing page, shown uppercase
  ///
  /// In en, this message translates to:
  /// **'Mainnet'**
  String get mainnetMigrationAllSetBadge;

  /// Title of the closing page
  ///
  /// In en, this message translates to:
  /// **'You\'re all set.'**
  String get mainnetMigrationAllSetTitle;

  /// Body of the closing page
  ///
  /// In en, this message translates to:
  /// **'Everything from here is real money. Add some {tokenSymbol} whenever you\'re ready.'**
  String mainnetMigrationAllSetBody(String tokenSymbol);

  /// Button on the closing page that opens the receive screen
  ///
  /// In en, this message translates to:
  /// **'Get {tokenSymbol}'**
  String mainnetMigrationGetTokens(String tokenSymbol);

  /// Button on the closing page that opens the wallet
  ///
  /// In en, this message translates to:
  /// **'Go to wallet'**
  String get mainnetMigrationGoToWallet;

  /// Toaster when the migration completion flag cannot be written
  ///
  /// In en, this message translates to:
  /// **'Could not save your choice: {error}'**
  String mainnetMigrationSaveFailed(String error);

  /// Settings hub row and screen title for testnet mining rewards
  ///
  /// In en, this message translates to:
  /// **'Mining Rewards'**
  String get settingsMiningRewards;

  /// Settings hub row subtitle for testnet mining rewards
  ///
  /// In en, this message translates to:
  /// **'Claim your testnet mining rewards'**
  String get settingsMiningRewardsSubtitle;

  /// Hero heading on the Airdrop entry screen
  ///
  /// In en, this message translates to:
  /// **'Testnet mining paid out in {symbol}.'**
  String miningRewardsHeroTitle(String symbol);

  /// Explainer under the hero heading on the Airdrop entry screen
  ///
  /// In en, this message translates to:
  /// **'Rewards are based on the blocks you mined on Resonance, Schrödinger, Dirac, and Planck testnets. Amounts are already set.'**
  String get miningRewardsHeroBody;

  /// Section label above the wallet list
  ///
  /// In en, this message translates to:
  /// **'Wallets on the device'**
  String get settingsSelectWalletSection;

  /// Label over the chain progress counter while the check runs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Checking 1 address} other{Checking {count} addresses}}'**
  String miningRewardsCheckingAddresses(int count);

  /// Unit after the number of chains checked so far
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String miningRewardsProgressOf(int total);

  /// Label over the summed payout
  ///
  /// In en, this message translates to:
  /// **'Total rewards'**
  String get miningRewardsTotalRewards;

  /// Blocks mined on one testnet, under the chain name
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 block} other{{count} blocks}}'**
  String miningRewardsBlocks(int count);

  /// Chain row value when the wallet owns no row in that table
  ///
  /// In en, this message translates to:
  /// **'Not mined'**
  String get miningRewardsNotMined;

  /// First row of the per-chain sheet
  ///
  /// In en, this message translates to:
  /// **'Blocks mined'**
  String get miningRewardsSheetBlocksMined;

  /// Second row of the per-chain sheet
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get miningRewardsSheetReward;

  /// Heading when every chain answered and none has a row for this wallet
  ///
  /// In en, this message translates to:
  /// **'No mining on this wallet'**
  String get miningRewardsNoMiningTitle;

  /// First paragraph of the no-mining page
  ///
  /// In en, this message translates to:
  /// **'We checked your addresses against Resonance, Schrödinger, Dirac and Planck, and found no blocks.'**
  String get miningRewardsNoMiningBody1;

  /// Second paragraph of the no-mining page
  ///
  /// In en, this message translates to:
  /// **'If you mined with a different wallet, go back and choose it.'**
  String get miningRewardsNoMiningBody2;

  /// Button on the no-mining page
  ///
  /// In en, this message translates to:
  /// **'Try another wallet'**
  String get miningRewardsTryAnotherWallet;

  /// Explainer under the total on the pay-to screen
  ///
  /// In en, this message translates to:
  /// **'Enter the address we should send the rewards to'**
  String get miningRewardsPayToIntro;

  /// Secondary button on the pay-to screen
  ///
  /// In en, this message translates to:
  /// **'Use Another Address'**
  String get miningRewardsUseAnotherAddress;

  /// Title of the typed-address screen
  ///
  /// In en, this message translates to:
  /// **'Another Address'**
  String get miningRewardsAnotherAddressTitle;

  /// Label above the typed-address field
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get miningRewardsDestinationLabel;

  /// Placeholder of the typed-address field
  ///
  /// In en, this message translates to:
  /// **'Paste {symbol} Address'**
  String miningRewardsPasteAddressHint(String symbol);

  /// Helper under the typed-address field
  ///
  /// In en, this message translates to:
  /// **'Use an address you control. Rewards sent to an address you don\'t own can\'t be recovered.'**
  String get miningRewardsAddressAdvice;

  /// Error under the typed-address field
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a valid {symbol} address. Check the last few characters.'**
  String miningRewardsAddressInvalid(String symbol);

  /// Title of the confirm screen
  ///
  /// In en, this message translates to:
  /// **'Confirm Destination'**
  String get miningRewardsConfirmTitle;

  /// Label over the amount on the confirm card
  ///
  /// In en, this message translates to:
  /// **'Claiming'**
  String get miningRewardsClaimingLabel;

  /// Summary row label on the confirm screen
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get miningRewardsAmountLabel;

  /// Summary row label on the confirm screen
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get miningRewardsPayoutLabel;

  /// How soon payouts go out, shown as the payout row value
  ///
  /// In en, this message translates to:
  /// **'Within a week'**
  String get miningRewardsPayoutWindow;

  /// Secondary button on the confirm screen
  ///
  /// In en, this message translates to:
  /// **'Change Details'**
  String get miningRewardsChangeDetails;

  /// Heading when the claim server rejected or was unreachable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit right now'**
  String get miningRewardsSubmitFailedTitle;

  /// First paragraph of the submission failed page
  ///
  /// In en, this message translates to:
  /// **'Something went wrong reaching the network.'**
  String get miningRewardsSubmitFailedBody1;

  /// Second paragraph of the submission failed page
  ///
  /// In en, this message translates to:
  /// **'Your rewards are safe. Nothing expires and there is no deadline to claim.'**
  String get miningRewardsSubmitFailedBody2;

  /// Heading when part of the batch was accepted and the rest failed
  ///
  /// In en, this message translates to:
  /// **'Some claims have been submitted'**
  String get miningRewardsSubmitPartialTitle;

  /// First paragraph under the partial-submission heading
  ///
  /// In en, this message translates to:
  /// **'Please try again to submit the rest.'**
  String get miningRewardsSubmitPartialBody;

  /// First line of the submitted page
  ///
  /// In en, this message translates to:
  /// **'All claims have been submitted.'**
  String get miningRewardsSubmittedAll;

  /// Destination line on the submitted page: an account name or a short address
  ///
  /// In en, this message translates to:
  /// **'Paying to {destination}.'**
  String miningRewardsSubmittedPayingTo(String destination);

  /// Closing line on the submitted page
  ///
  /// In en, this message translates to:
  /// **'Payouts go out within a week. Nothing else to do.'**
  String get miningRewardsSubmittedNote;

  /// Label over the amount when the wallet already submitted its claim
  ///
  /// In en, this message translates to:
  /// **'Claimed {date}'**
  String miningRewardsClaimedOn(String date);

  /// Row label on the already-claimed page
  ///
  /// In en, this message translates to:
  /// **'Paying To'**
  String get miningRewardsPayingTo;

  /// Button on the already-claimed page
  ///
  /// In en, this message translates to:
  /// **'Check another wallet'**
  String get miningRewardsCheckAnotherWallet;

  /// Label over the wallet list on the mining rewards entry page
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get miningRewardsWalletsLabel;

  /// Caption under the amount a wallet has already claimed
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get miningRewardsClaimedTag;

  /// Wallet row value on the entry page when nothing was claimed
  ///
  /// In en, this message translates to:
  /// **'Not claimed yet'**
  String get miningRewardsNotClaimed;

  /// Button starting the mining rewards eligibility check
  ///
  /// In en, this message translates to:
  /// **'Check eligibility'**
  String get miningRewardsCheckEligibility;

  /// Shown next to a matched address whose key era the claim server does not accept yet
  ///
  /// In en, this message translates to:
  /// **'Claim not available yet'**
  String get miningRewardsNotClaimable;

  /// Shown in a chain row when its eligibility check threw
  ///
  /// In en, this message translates to:
  /// **'Check failed, tap to retry'**
  String get miningRewardsCheckFailed;

  /// Button opening the claim beneficiary screen
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get miningRewardsClaim;

  /// Button that proves ownership and submits the claims
  ///
  /// In en, this message translates to:
  /// **'Submit Claim'**
  String get miningRewardsSubmitClaims;

  /// Desktop app menu item that opens Settings; the ellipsis shows it opens a sheet
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get desktopMenuSettings;

  /// Desktop menu bar: File menu title
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get desktopMenuFile;

  /// Desktop File menu item that closes the app window
  ///
  /// In en, this message translates to:
  /// **'Close Window'**
  String get desktopMenuCloseWindow;

  /// Desktop menu bar: title of the menu holding the active account's actions
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get desktopMenuAccount;

  /// Desktop: the item that adds a Transparent account to a wallet, at once, with its name ready to be typed over; in the Account menu and the sidebar's Add Account menu
  ///
  /// In en, this message translates to:
  /// **'New Account'**
  String get desktopMenuNewAccount;

  /// Desktop menu bar: View menu title
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get desktopMenuView;

  /// Desktop View menu item shown while the sidebar is visible
  ///
  /// In en, this message translates to:
  /// **'Hide Sidebar'**
  String get desktopMenuHideSidebar;

  /// Desktop View menu item shown while the sidebar is hidden
  ///
  /// In en, this message translates to:
  /// **'Show Sidebar'**
  String get desktopMenuShowSidebar;

  /// Desktop View menu item that selects the row under the selected one in the sidebar, the first after the last
  ///
  /// In en, this message translates to:
  /// **'Next Sidebar Item'**
  String get desktopMenuNextSidebarItem;

  /// Desktop View menu item that selects the row above the selected one in the sidebar, the last before the first
  ///
  /// In en, this message translates to:
  /// **'Previous Sidebar Item'**
  String get desktopMenuPreviousSidebarItem;

  /// Desktop View menu item, and its name in Settings › Keyboard Shortcuts, that reads the balances, activity and proposals again from the network
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get desktopMenuRefresh;

  /// Desktop menu bar: Window menu title
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get desktopMenuWindow;

  /// Desktop boot intro, a terminal-style line: the protocol's name and version
  ///
  /// In en, this message translates to:
  /// **'> QUANTUS PROTOCOL v1.0.0-gm'**
  String get desktopBootProtocol;

  /// Desktop boot intro line; {status} is desktopBootStatusOk
  ///
  /// In en, this message translates to:
  /// **'> NIST FIPS 204 MODULE LOADED {status}'**
  String desktopBootNistModule(String status);

  /// Desktop boot intro line; {scheme} is the signature scheme's name, not translated
  ///
  /// In en, this message translates to:
  /// **'> INITIALIZING {scheme}...'**
  String desktopBootInitializing(String scheme);

  /// Desktop boot intro line; {status} is desktopBootStatusActive
  ///
  /// In en, this message translates to:
  /// **'> POST-QUANTUM SIGNATURE SCHEME {status}'**
  String desktopBootSignatureScheme(String status);

  /// Desktop boot intro line; {status} is desktopBootStatusReady
  ///
  /// In en, this message translates to:
  /// **'> RECURSIVE ZK PROOF ENGINE {status}'**
  String desktopBootZkEngine(String status);

  /// Desktop boot intro line; {status} is desktopBootStatusLoading
  ///
  /// In en, this message translates to:
  /// **'> CHLADNI FIELD VISUALIZER {status}'**
  String desktopBootChladni(String status);

  /// Desktop boot intro: status shown in green at the end of a line
  ///
  /// In en, this message translates to:
  /// **'[OK]'**
  String get desktopBootStatusOk;

  /// Desktop boot intro: status shown in green at the end of a line
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get desktopBootStatusActive;

  /// Desktop boot intro: status shown in green at the end of a line
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get desktopBootStatusReady;

  /// Desktop boot intro: status shown in orange at the end of a line
  ///
  /// In en, this message translates to:
  /// **'LOADING'**
  String get desktopBootStatusLoading;

  /// Desktop Welcome: label above the wave mode of the animated background, e.g. 2,3
  ///
  /// In en, this message translates to:
  /// **'WAVE MODE (m,n)'**
  String get desktopWaveModeLabel;

  /// Desktop Welcome: hint under the wave mode that moving the mouse changes the background's pattern
  ///
  /// In en, this message translates to:
  /// **'MOVE CURSOR TO SHIFT FREQUENCY'**
  String get desktopWaveModeHint;

  /// Desktop Welcome: short line above the headline, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'Quantum-Secure Encrypted Money'**
  String get desktopWelcomeEyebrow;

  /// Desktop Welcome: first line of the headline, continued by desktopWelcomeTitleLine2
  ///
  /// In en, this message translates to:
  /// **'Money quantum'**
  String get desktopWelcomeTitleLine1;

  /// Desktop Welcome: second line of the headline
  ///
  /// In en, this message translates to:
  /// **'computers can’t break.'**
  String get desktopWelcomeTitleLine2;

  /// Desktop Welcome: sentence under the headline, above the two buttons
  ///
  /// In en, this message translates to:
  /// **'Create a new wallet, or import one you already have.'**
  String get desktopWelcomeBody;

  /// Desktop account panel: label over the account's balance, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get desktopBalanceLabel;

  /// Desktop Import Wallet: the headline
  ///
  /// In en, this message translates to:
  /// **'Restore your wallet.'**
  String get desktopImportHeadline;

  /// Desktop Import Wallet: first tip beside the field, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'12 or 24 words'**
  String get desktopImportTipWordCount;

  /// Desktop Import Wallet: second tip, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'Separated by spaces'**
  String get desktopImportTipSpaces;

  /// Desktop Import Wallet: third tip, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'Paste the whole phrase at once'**
  String get desktopImportTipPaste;

  /// Desktop Import Wallet: label above the recovery phrase field, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get desktopImportPhraseLabel;

  /// Desktop Import Wallet: button in the field that pastes the clipboard's text into it
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get desktopImportPaste;

  /// Desktop Import Wallet: how many words have been typed into the field, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String desktopImportWordCount(int count);

  /// Desktop Wallet Created: the headline
  ///
  /// In en, this message translates to:
  /// **'Your wallet is ready.'**
  String get desktopWalletReadyHeadline;

  /// Desktop Wallet Created: sentence under the headline; {account} is the new account's name, {encrypted} is createAccountEncryptedDefaultName
  ///
  /// In en, this message translates to:
  /// **'{account} is transparent: fast, and visible on chain. The {encrypted} is for private transactions, and slower.'**
  String desktopWalletReadyBody(String account, String encrypted);

  /// Desktop Receive sheet: label above the encrypted account's next unused deposit address, shown in capitals
  ///
  /// In en, this message translates to:
  /// **'Deposit address'**
  String get desktopReceiveDepositAddressLabel;

  /// Desktop Receive sheet: notice on the encrypted account, why its deposit address changes
  ///
  /// In en, this message translates to:
  /// **'A new address once this one has been paid, so your deposits can’t be linked to each other.'**
  String get desktopReceiveEncryptedNotice;

  /// Desktop: what a Copy action says for a moment after it has copied
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get desktopCopied;

  /// Desktop Settings: under Recovery Phrase and Reset Wallet on a Mac with no login password to approve with
  ///
  /// In en, this message translates to:
  /// **'Set up a login password for this Mac to use this.'**
  String get desktopApprovalNeedsMacPassword;

  /// Desktop Settings: under Recovery Phrase and Reset Wallet on a Windows PC without Windows Hello
  ///
  /// In en, this message translates to:
  /// **'Set up Windows Hello to use this.'**
  String get desktopApprovalNeedsWindowsHello;

  /// Desktop Settings: under Recovery Phrase and Reset Wallet on a Linux system where the file that lets the app check the login password is not installed
  ///
  /// In en, this message translates to:
  /// **'Install Quantus Wallet’s PAM service (/etc/pam.d/quantus-wallet) to use this.'**
  String get desktopApprovalNeedsLinuxService;

  /// Desktop, Linux: the system's login asked for something besides the password, such as a one-time code, so approval could not be given
  ///
  /// In en, this message translates to:
  /// **'This computer’s login asks for more than a password, which Quantus Wallet can’t answer yet.'**
  String get desktopApprovalLoginAsksMore;

  /// Desktop, Linux: title of the dialog that asks for the computer's login password to approve an action
  ///
  /// In en, this message translates to:
  /// **'Enter your login password'**
  String get desktopPasswordPromptTitle;

  /// Desktop, Linux: placeholder and screen reader name of the login password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get desktopPasswordPromptHint;

  /// Desktop, Linux: the button that submits the login password
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get desktopPasswordPromptConfirm;

  /// Desktop, Linux: under the login password field after the system refused the password
  ///
  /// In en, this message translates to:
  /// **'That password is not right. Try again.'**
  String get desktopPasswordPromptWrong;

  /// Desktop Settings: the system's approval prompt itself failed
  ///
  /// In en, this message translates to:
  /// **'Couldn’t ask for approval: {error}'**
  String desktopApprovalFailed(String error);

  /// Desktop Settings: small capitals over the caution shown before the recovery phrase
  ///
  /// In en, this message translates to:
  /// **'Before you look'**
  String get desktopRecoveryPhraseEyebrow;

  /// Desktop Settings: small capitals over the caution shown before resetting the wallet
  ///
  /// In en, this message translates to:
  /// **'Cannot be undone'**
  String get desktopResetEyebrow;

  /// Desktop Settings: masks the recovery phrase's words
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get desktopRecoveryPhraseHide;

  /// Desktop Settings: unmasks the recovery phrase's words
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get desktopRecoveryPhraseShow;

  /// Desktop Settings: the stored recovery phrase is missing
  ///
  /// In en, this message translates to:
  /// **'This wallet’s recovery phrase could not be read.'**
  String get desktopRecoveryPhraseUnreadable;

  /// Desktop Settings: copying the recovery phrase, kept out of clipboard history, failed
  ///
  /// In en, this message translates to:
  /// **'Couldn’t copy the recovery phrase.'**
  String get desktopRecoveryPhraseCopyFailed;

  /// Desktop Send: placeholder of the recipient's address field
  ///
  /// In en, this message translates to:
  /// **'Quantus address'**
  String get desktopSendAddressHint;

  /// Desktop Send: under the address field when what it holds is not a valid address
  ///
  /// In en, this message translates to:
  /// **'This is not a Quantus address.'**
  String get desktopSendAddressInvalid;

  /// Desktop Send: under the address field when it holds the sending account's own address
  ///
  /// In en, this message translates to:
  /// **'You can’t send to the account you’re sending from.'**
  String get desktopSendAddressSelf;

  /// Desktop Send: label before the balance that can be spent, under the amount field
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get desktopSendAvailable;

  /// Desktop Send: under the amount field when the amount and its fee exceed the balance. amount is the most that can be sent, with the token symbol
  ///
  /// In en, this message translates to:
  /// **'More than the {amount} you can send.'**
  String desktopSendAmountTooMuch(String amount);

  /// Desktop Send: checkbox under the amount field. While ticked the amount is everything the fee leaves of the balance
  ///
  /// In en, this message translates to:
  /// **'Send the maximum amount'**
  String get desktopSendMaximum;

  /// Desktop Send: label of what a private send from the Encrypted account costs, on the form, the review and the receipt
  ///
  /// In en, this message translates to:
  /// **'Transaction fee'**
  String get desktopSendTransactionFee;

  /// Desktop Send: status at the end of a private send's progress line that a cancel interrupted, in the terminal's voice like [OK]
  ///
  /// In en, this message translates to:
  /// **'[STOPPED]'**
  String get desktopSendStatusStopped;

  /// Desktop Send: status at the end of a private send's progress line at which the send failed, in the terminal's voice like [OK]
  ///
  /// In en, this message translates to:
  /// **'[FAILED]'**
  String get desktopSendStatusFailed;

  /// Desktop Send: the button that opens the review step, and that step's name in the sheet's path
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get desktopSendReview;

  /// Desktop Send: label of the total, amount plus fee, on the receipt shown once a send is submitted
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get desktopSendYouPaid;

  /// Desktop Send: small capitals over the receipt, once the send was handed to the network
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get desktopSendSubmitted;

  /// Desktop: opens a transaction in the block explorer, in the browser
  ///
  /// In en, this message translates to:
  /// **'View in Explorer'**
  String get desktopViewInExplorer;

  /// Desktop Send: on the receipt of a private send that took several transactions, the name of one of them, before the action that opens it in the explorer
  ///
  /// In en, this message translates to:
  /// **'Transaction {index} of {count}'**
  String desktopSendTransactionOf(int index, int count);

  /// Desktop: title of the dialog shown when an account chosen in the sidebar, the menu or by a shortcut could not be made the active account
  ///
  /// In en, this message translates to:
  /// **'Could not switch account'**
  String get desktopAccountSwitchFailedTitle;

  /// Desktop: the dialog's message when switching account failed; {account} is the account's name, {error} the reason. What was asked for after the switch is not done.
  ///
  /// In en, this message translates to:
  /// **'{account} could not be made the active account: {error}'**
  String desktopAccountSwitchFailedMessage(String account, String error);

  /// Desktop Settings: the row that opens the keyboard shortcuts, and that step's name in the sheet's path
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get settingsKeyboardShortcuts;

  /// Desktop Settings: the line under Keyboard Shortcuts
  ///
  /// In en, this message translates to:
  /// **'Change the keys that open and move around the wallet'**
  String get settingsKeyboardShortcutsSubtitle;

  /// Desktop Keyboard Shortcuts: the command that shows or hides the sidebar
  ///
  /// In en, this message translates to:
  /// **'Show or Hide Sidebar'**
  String get desktopShortcutsToggleSidebar;

  /// Desktop Keyboard Shortcuts: the row whose keys, held with a digit, make the account of that number in the sidebar active
  ///
  /// In en, this message translates to:
  /// **'Go to account 1 to 9'**
  String get desktopShortcutsAccounts;

  /// Desktop Keyboard Shortcuts: shown in place of the keys of a command that has no shortcut
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get desktopShortcutsNone;

  /// Desktop Keyboard Shortcuts: shown in a shortcut's place while it waits for new keys
  ///
  /// In en, this message translates to:
  /// **'Type shortcut…'**
  String get desktopShortcutsRecording;

  /// Desktop Keyboard Shortcuts: the line under a shortcut that waits for new keys
  ///
  /// In en, this message translates to:
  /// **'Press the new keys. Esc cancels; Delete removes the shortcut.'**
  String get desktopShortcutsRecordingHint;

  /// Desktop Keyboard Shortcuts, macOS: why keys pressed without a modifier were not taken; the key names are as printed on the keyboard
  ///
  /// In en, this message translates to:
  /// **'Hold Command, Option or Control with the key.'**
  String get desktopShortcutsNeedsModifierMac;

  /// Desktop Keyboard Shortcuts, Windows and Linux: why keys pressed without a modifier were not taken; the key names are as printed on the keyboard
  ///
  /// In en, this message translates to:
  /// **'Hold Ctrl or Alt with the key.'**
  String get desktopShortcutsNeedsModifierPc;

  /// Desktop Keyboard Shortcuts, Windows and Linux: why keys held with the Windows (Super) key were not taken
  ///
  /// In en, this message translates to:
  /// **'Shortcuts with the Windows or Super key belong to the system.'**
  String get desktopShortcutsSystemKey;

  /// Desktop Keyboard Shortcuts, macOS: why keys were not taken when the key pressed (one of the number pad, for instance) cannot be a menu item's shortcut in the system's menu bar
  ///
  /// In en, this message translates to:
  /// **'The menu bar cannot use that key. Press other keys.'**
  String get desktopShortcutsKeyNotForMenuBar;

  /// Desktop Keyboard Shortcuts: the note at the foot of the list, about the commands whose keys cannot be changed
  ///
  /// In en, this message translates to:
  /// **'Settings, Close Window and Quit keep the system\'s keys.'**
  String get desktopShortcutsFixedNote;

  /// Desktop Keyboard Shortcuts: the button that puts every shortcut back as the app shipped it
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get desktopShortcutsRestoreDefaults;

  /// Desktop Keyboard Shortcuts: shown when the stored shortcuts were unreadable at start
  ///
  /// In en, this message translates to:
  /// **'Your saved shortcuts could not be read, so the defaults are in use.'**
  String get desktopShortcutsUnreadable;

  /// Desktop: the system command that quits the app, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get desktopSystemQuit;

  /// Desktop, macOS: the system command that hides the app, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get desktopSystemHide;

  /// Desktop, macOS: the system command that hides the other apps, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Hide Others'**
  String get desktopSystemHideOthers;

  /// Desktop, macOS: the system command that minimizes the window, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get desktopSystemMinimize;

  /// Desktop, macOS: the system command that makes the window full screen, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Full Screen'**
  String get desktopSystemFullScreen;

  /// Desktop: the editing command, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get desktopSystemCut;

  /// Desktop: the editing command, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get desktopSystemCopy;

  /// Desktop: the editing command, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get desktopSystemPaste;

  /// Desktop: the editing command, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get desktopSystemSelectAll;

  /// Desktop: the editing command, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get desktopSystemUndo;

  /// Desktop: the editing command, named when its keys are refused as a shortcut
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get desktopSystemRedo;

  /// Desktop Keyboard Shortcuts: why recorded keys were not taken; {command} is the name of the command that has them
  ///
  /// In en, this message translates to:
  /// **'That shortcut is already used by {command}. Press other keys.'**
  String desktopShortcutsUsedBy(String command);

  /// Desktop Keyboard Shortcuts: why recorded keys were not taken; {command} is the system command they belong to
  ///
  /// In en, this message translates to:
  /// **'That shortcut is kept for {command}. Press other keys.'**
  String desktopShortcutsKeptFor(String command);

  /// Desktop Keyboard Shortcuts: why a choice of keys for the account shortcuts was not taken; {command} is the command that uses one of the resulting shortcuts
  ///
  /// In en, this message translates to:
  /// **'Those keys would clash with {command}.'**
  String desktopShortcutsModifierUsedBy(String command);

  /// Desktop Keyboard Shortcuts: shown when a change could not be stored; {error} is the reason
  ///
  /// In en, this message translates to:
  /// **'The shortcut could not be saved: {error}'**
  String desktopShortcutsSaveFailed(String error);

  /// Desktop Propose: the label, under the amount, of what proposing costs the member in all (network fee, deposit and proposal fee)
  ///
  /// In en, this message translates to:
  /// **'Proposal cost'**
  String get desktopProposeCost;

  /// Desktop Propose: what proposing costs, followed by the badge and name of the member's account that pays it
  ///
  /// In en, this message translates to:
  /// **'{cost}, paid by'**
  String desktopProposeCostPaidBy(String cost);

  /// Desktop Propose: under the amount, when the member's own account cannot pay what proposing costs
  ///
  /// In en, this message translates to:
  /// **'{account} does not hold enough to pay the proposal cost.'**
  String desktopProposeCostNotCovered(String account);

  /// Desktop Propose: the checkbox under the amount that proposes the multisig's whole balance
  ///
  /// In en, this message translates to:
  /// **'Propose the maximum amount'**
  String get desktopProposeMaximum;

  /// Desktop Propose review: the small label over the amount; drawn in capitals
  ///
  /// In en, this message translates to:
  /// **'Proposing'**
  String get desktopProposeProposing;

  /// Desktop Propose review: the row naming the member's account that proposes
  ///
  /// In en, this message translates to:
  /// **'Proposed by'**
  String get desktopProposeProposedBy;

  /// Desktop Propose review: the row saying how many of the multisig's signers must approve
  ///
  /// In en, this message translates to:
  /// **'Approvals needed'**
  String get desktopProposeApprovalsNeeded;

  /// Desktop Propose receipt: the row saying how many approvals the proposal has of those it needs
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get desktopProposeApprovals;

  /// Desktop Propose: a count out of a total, as in "2 of 3" signers or "1 of 2" approvals
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String desktopProposeCountOf(int count, int total);

  /// Desktop Propose: the row saying when the proposal expires
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get desktopProposeExpires;

  /// Desktop Propose review: the row of the deposit held while the proposal is open
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get desktopProposeDeposit;

  /// Desktop Propose review: the row of the fee the chain charges for creating a proposal
  ///
  /// In en, this message translates to:
  /// **'Proposal fee'**
  String get desktopProposeFee;

  /// Desktop Propose review: follows the badge and name of the member's account on the total's row, as in "Account 1 pays"
  ///
  /// In en, this message translates to:
  /// **'pays'**
  String get desktopProposePays;

  /// Desktop Propose receipt: follows the badge and name of the member's account on the total's row, as in "Account 1 paid"
  ///
  /// In en, this message translates to:
  /// **'paid'**
  String get desktopProposePaid;

  /// Desktop Propose review: the button that submits the proposal
  ///
  /// In en, this message translates to:
  /// **'Submit Proposal'**
  String get desktopProposeSubmit;

  /// Desktop Propose receipt: the headline once the network has created the proposal; the amount comes with its token symbol, as in "250 QTC proposed"
  ///
  /// In en, this message translates to:
  /// **'{amount} proposed'**
  String desktopProposeProposed(String amount);

  /// Desktop Propose receipt: small capitals over the receipt while the network has not yet created the proposal
  ///
  /// In en, this message translates to:
  /// **'Confirming'**
  String get desktopProposeConfirming;

  /// Desktop Propose receipt: small capitals over the receipt when the wallet stopped waiting for the network to create the proposal
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get desktopProposeNotConfirmed;

  /// Desktop Propose receipt: the headline until the network has created the proposal; the amount comes with its token symbol, as in "Proposing 250 QTC"
  ///
  /// In en, this message translates to:
  /// **'Proposing {amount}'**
  String desktopProposeProposingAmount(String amount);

  /// Desktop Propose receipt: the line under the headline while the proposal's transaction was broadcast and the network has not yet created the proposal
  ///
  /// In en, this message translates to:
  /// **'Waiting for the network to create the proposal.'**
  String get desktopProposeWaiting;

  /// Desktop proposal panel: where an open proposal stands once it has all the approvals it needs and waits to be executed; drawn in small capitals
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get desktopProposalApproved;

  /// Desktop proposal panel: where an open proposal stands once it is past its expiry block, drawn in small capitals; also the label of the row that says when it expired, in place of "Expires"
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get desktopProposalExpired;

  /// Desktop proposal panel: the sentence under "Invalid proposal" for a proposal whose call this wallet cannot decode
  ///
  /// In en, this message translates to:
  /// **'This wallet can\'t read what this proposal would do, so it can\'t be approved or executed here.'**
  String get desktopProposalUnreadable;

  /// Desktop footer: the network the wallet is on, beside a dot that is green while online
  ///
  /// In en, this message translates to:
  /// **'Mainnet'**
  String get desktopFooterMainnet;

  /// Desktop footer: the network the wallet is on when built for the test network
  ///
  /// In en, this message translates to:
  /// **'Testnet'**
  String get desktopFooterTestnet;

  /// Desktop footer: in place of the network's name while the computer has no network
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get desktopFooterOffline;

  /// Desktop footer: the wallet is reading its balance and activity from the network now
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get desktopFooterSyncing;

  /// Desktop footer: the wallet's balance was read from the network less than a minute ago
  ///
  /// In en, this message translates to:
  /// **'Synced just now'**
  String get desktopFooterSyncedJustNow;

  /// Desktop footer: how long ago the wallet's balance was last read from the network, in minutes
  ///
  /// In en, this message translates to:
  /// **'Synced {minutes}m ago'**
  String desktopFooterSyncedMinutesAgo(int minutes);

  /// Desktop footer: how long ago the wallet's balance was last read from the network, in hours
  ///
  /// In en, this message translates to:
  /// **'Synced {hours}h ago'**
  String desktopFooterSyncedHoursAgo(int hours);

  /// Desktop footer: how long ago the wallet's balance was last read from the network, in days
  ///
  /// In en, this message translates to:
  /// **'Synced {days}d ago'**
  String desktopFooterSyncedDaysAgo(int days);

  /// Desktop footer: the latest read of the wallet's balance from the network failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync'**
  String get desktopFooterSyncFailed;

  /// Desktop footer: the chain's latest block, its number already formatted with digit grouping
  ///
  /// In en, this message translates to:
  /// **'Block {number}'**
  String desktopFooterBlock(String number);

  /// Desktop footer: the app's name and version, at the footer's right end
  ///
  /// In en, this message translates to:
  /// **'Quantus Wallet {version}'**
  String desktopFooterVersion(String version);

  /// Desktop: title of the panel listing the open account's transfers still under way, above Activity
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get desktopActivityInProgress;

  /// Desktop: shown in the Activity panel when the account's history could not be loaded, above the error
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the activity'**
  String get desktopActivityLoadFailed;

  /// Desktop: a note at the top of the Activity panel when a refresh failed; the rows already shown stay under it, with Try Again beside it
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh the activity'**
  String get desktopActivityRefreshFailed;

  /// Desktop: heading of the popover shown on hovering one of the wallet's own accounts named as a sender or receiver; the account's whole address and its checkphrase are under it, with Copy beside it
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get desktopMarksAddress;

  /// Desktop, read by screen readers: how many of an account's transfers are still in progress, as the count on its badge in the sidebar says
  ///
  /// In en, this message translates to:
  /// **'{count} in progress'**
  String desktopMarksInProgress(int count);

  /// Desktop, read by screen readers: how many of a multisig's open proposals wait for a signature from this wallet, as the count on its badge in the sidebar says
  ///
  /// In en, this message translates to:
  /// **'{count} waiting for your signature'**
  String desktopMarksWaitingForSignature(int count);

  /// Desktop: beside the Scheduled status of a reversible transfer, how long until it runs; time is like 00d:23h:41m
  ///
  /// In en, this message translates to:
  /// **'in {time}'**
  String desktopActivityRunsIn(String time);

  /// Desktop: title of the panel showing one transaction, and the label over its hash
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get desktopActivityTransaction;

  /// Desktop transaction panel: the amount a multisig proposal moves
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get desktopActivityAmount;

  /// Desktop transaction panel: how many of a new multisig's signers must approve, of how many
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get desktopActivityThreshold;

  /// Desktop transaction panel: how many signers a new multisig has
  ///
  /// In en, this message translates to:
  /// **'Signers'**
  String get desktopActivitySigners;

  /// Desktop transaction panel: the account that made a multisig
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get desktopActivityCreatedBy;

  /// Desktop transaction panel: the fee the chain charges for making a multisig
  ///
  /// In en, this message translates to:
  /// **'Multisig fee'**
  String get desktopActivityCreationFee;

  /// Desktop account menu: opens the account’s Info sheet
  ///
  /// In en, this message translates to:
  /// **'Get Info'**
  String get desktopAccountGetInfo;

  /// Desktop account menu: copies the account’s address
  ///
  /// In en, this message translates to:
  /// **'Copy Address'**
  String get desktopAccountCopyAddress;

  /// Desktop account menu: copies the encrypted account’s inner hash
  ///
  /// In en, this message translates to:
  /// **'Copy Inner Hash'**
  String get desktopAccountCopyInnerHash;

  /// Desktop account menu: starts renaming the account
  ///
  /// In en, this message translates to:
  /// **'Rename…'**
  String get desktopAccountRename;

  /// Desktop account and wallet menus: opens the wallet’s recovery phrase steps
  ///
  /// In en, this message translates to:
  /// **'Show Recovery Phrase…'**
  String get desktopAccountShowRecoveryPhrase;

  /// Desktop multisig menu: opens the multisig’s Info sheet with its signers
  ///
  /// In en, this message translates to:
  /// **'Show Signers…'**
  String get desktopAccountShowSigners;

  /// Desktop account menu: starts disconnecting the account
  ///
  /// In en, this message translates to:
  /// **'Disconnect Account…'**
  String get desktopAccountDisconnectAccount;

  /// Desktop account menu: starts disconnecting a hardware account
  ///
  /// In en, this message translates to:
  /// **'Disconnect Hardware Account…'**
  String get desktopAccountDisconnectHardware;

  /// Desktop multisig menu: starts disconnecting the multisig
  ///
  /// In en, this message translates to:
  /// **'Disconnect Multisig…'**
  String get desktopAccountDisconnectMultisig;

  /// Desktop: shown on the account’s row after its address was copied
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get desktopAccountAddressCopied;

  /// Desktop: shown on the encrypted account’s row after its inner hash was copied
  ///
  /// In en, this message translates to:
  /// **'Inner hash copied'**
  String get desktopAccountInnerHashCopied;

  /// Desktop: shown on the account’s row when copying failed
  ///
  /// In en, this message translates to:
  /// **'Couldn’t copy: {error}'**
  String desktopAccountCopyFailed(String error);

  /// Desktop Info sheet title for an account
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get desktopAccountInfoTitle;

  /// Desktop Info sheet title for a multisig
  ///
  /// In en, this message translates to:
  /// **'Multisig Info'**
  String get desktopMultisigInfoTitle;

  /// Desktop Info sheet: label of the group with the account’s name and address
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get desktopAccountInfoAccount;

  /// Desktop Info sheet: label of the group with the multisig’s name, address and threshold
  ///
  /// In en, this message translates to:
  /// **'Multisig'**
  String get desktopAccountInfoMultisig;

  /// Desktop Info sheet: label of the group listing a multisig’s signers
  ///
  /// In en, this message translates to:
  /// **'Signers'**
  String get desktopAccountInfoSigners;

  /// Desktop Info sheet: label of the group with what applies to this device only
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get desktopAccountInfoThisDevice;

  /// Desktop Info sheet: label of the encrypted account’s inner hash group
  ///
  /// In en, this message translates to:
  /// **'Mining rewards'**
  String get desktopAccountInfoMiningRewards;

  /// Desktop Info sheet: the name row’s title
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get desktopAccountInfoName;

  /// Desktop Info sheet: under the name row’s title
  ///
  /// In en, this message translates to:
  /// **'Shown only in this app'**
  String get desktopAccountInfoNameSubtitle;

  /// Desktop Info sheet: the multisig threshold row’s title
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get desktopAccountInfoThreshold;

  /// Desktop Info sheet: under the threshold row’s title
  ///
  /// In en, this message translates to:
  /// **'Signatures a proposal needs before it can run'**
  String get desktopAccountInfoThresholdSubtitle;

  /// Desktop Info sheet: under Recovery Phrase; wallet is the wallet’s name
  ///
  /// In en, this message translates to:
  /// **'The 24 words of {wallet}, which this account is in'**
  String desktopAccountInfoPhraseSubtitle(String wallet);

  /// Desktop Info sheet: the encrypted account’s inner hash row’s title
  ///
  /// In en, this message translates to:
  /// **'Inner Hash'**
  String get desktopAccountInfoInnerHash;

  /// Desktop Info sheet: what the inner hash is for
  ///
  /// In en, this message translates to:
  /// **'Give it to your miner as --rewards-inner-hash, and block rewards land in this account.'**
  String get desktopAccountInfoInnerHashCaption;

  /// Desktop Info sheet: mark on the signer who created the multisig
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get desktopAccountInfoCreator;

  /// Desktop Info sheet: mark on the signer that is this wallet’s account
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get desktopAccountInfoYou;

  /// Desktop Info sheet: the row that starts disconnecting the account
  ///
  /// In en, this message translates to:
  /// **'Disconnect Account'**
  String get desktopAccountInfoDisconnectAccount;

  /// Desktop Info sheet: under Disconnect Account
  ///
  /// In en, this message translates to:
  /// **'Stops showing {name} in this app; {wallet} keeps its recovery phrase'**
  String desktopAccountInfoDisconnectAccountSubtitle(String name, String wallet);

  /// Desktop Info sheet: under Disconnect Account when it is the wallet’s last account
  ///
  /// In en, this message translates to:
  /// **'{name} is the last account in {wallet}, so the wallet goes with it'**
  String desktopAccountInfoDisconnectWalletSubtitle(String name, String wallet);

  /// Desktop Info sheet: the row that starts disconnecting a hardware account
  ///
  /// In en, this message translates to:
  /// **'Disconnect Hardware Account'**
  String get desktopAccountInfoDisconnectHardware;

  /// Desktop Info sheet: under Disconnect Hardware Account
  ///
  /// In en, this message translates to:
  /// **'Stops showing {name} in this app; your device keeps its keys'**
  String desktopAccountInfoDisconnectHardwareSubtitle(String name);

  /// Desktop Info sheet: the row that starts disconnecting the multisig
  ///
  /// In en, this message translates to:
  /// **'Disconnect Multisig'**
  String get desktopAccountInfoDisconnectMultisig;

  /// Desktop Info sheet: under Disconnect Multisig
  ///
  /// In en, this message translates to:
  /// **'Stops showing {name} in this app; it stays on the chain'**
  String desktopAccountInfoDisconnectMultisigSubtitle(String name);

  /// Desktop Info sheet: the Disconnect step’s name in the sheet’s path
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get desktopDisconnectTitle;

  /// Desktop Disconnect step: headline for an account, a hardware account or a multisig
  ///
  /// In en, this message translates to:
  /// **'Stop showing {name}?'**
  String desktopDisconnectHeadline(String name);

  /// Desktop Disconnect step: small capitals over the caution for an account
  ///
  /// In en, this message translates to:
  /// **'Disconnect account'**
  String get desktopDisconnectAccountEyebrow;

  /// Desktop Disconnect step: first line for an account
  ///
  /// In en, this message translates to:
  /// **'{name} leaves this app; its funds stay on the blockchain'**
  String desktopDisconnectAccountLine1(String name);

  /// Desktop Disconnect step: second line for an account
  ///
  /// In en, this message translates to:
  /// **'{wallet} keeps its recovery phrase, so you can add {name} back later'**
  String desktopDisconnectAccountLine2(String name, String wallet);

  /// Desktop Disconnect step: small capitals over the caution for a hardware account
  ///
  /// In en, this message translates to:
  /// **'Disconnect hardware account'**
  String get desktopDisconnectHardwareEyebrow;

  /// Desktop Disconnect step: second line for a hardware account
  ///
  /// In en, this message translates to:
  /// **'Your hardware wallet keeps its keys, so you can connect it again later'**
  String get desktopDisconnectHardwareLine2;

  /// Desktop Disconnect step: small capitals over the caution for a multisig
  ///
  /// In en, this message translates to:
  /// **'Disconnect multisig'**
  String get desktopDisconnectMultisigEyebrow;

  /// Desktop Disconnect step: first line for a multisig
  ///
  /// In en, this message translates to:
  /// **'{name} leaves this app; it stays on the chain with its signers'**
  String desktopDisconnectMultisigLine1(String name);

  /// Desktop Disconnect step: second line for a multisig
  ///
  /// In en, this message translates to:
  /// **'You can add it back later'**
  String get desktopDisconnectMultisigLine2;

  /// Desktop Disconnect step: headline when the account is its wallet’s last
  ///
  /// In en, this message translates to:
  /// **'This removes {wallet}'**
  String desktopDisconnectWalletHeadline(String wallet);

  /// Desktop Disconnect step: first line when the account is its wallet’s last
  ///
  /// In en, this message translates to:
  /// **'{name} is the last account in {wallet}, so the whole wallet goes with it'**
  String desktopDisconnectWalletLine1(String name, String wallet);

  /// Desktop Disconnect step: second line when the account is its wallet’s last
  ///
  /// In en, this message translates to:
  /// **'{wallet}’s recovery phrase will be deleted from this device'**
  String desktopDisconnectWalletLine2(String wallet);

  /// Desktop Disconnect step: third line when the account is its wallet’s last
  ///
  /// In en, this message translates to:
  /// **'Its funds stay on the blockchain, but only that phrase can restore them'**
  String get desktopDisconnectWalletLine3;

  /// Desktop Disconnect step: the box to tick before a wallet can be deleted
  ///
  /// In en, this message translates to:
  /// **'I’ve backed up {wallet}’s recovery phrase'**
  String desktopDisconnectWalletBackedUp(String wallet);

  /// Desktop: the reason the system shows when asking to approve deleting a wallet
  ///
  /// In en, this message translates to:
  /// **'Delete {wallet} and its recovery phrase'**
  String desktopDisconnectWalletReason(String wallet);

  /// Desktop Disconnect step: shown when the approval to delete a wallet was declined
  ///
  /// In en, this message translates to:
  /// **'Deleting {wallet} needs your approval'**
  String desktopDisconnectWalletDeclined(String wallet);

  /// Desktop Settings: under Recovery Phrase when there are several wallets
  ///
  /// In en, this message translates to:
  /// **'View the 24 words of each of your {count} wallets'**
  String desktopRecoveryPhraseWalletsSubtitle(int count);

  /// Desktop Settings: label over the list of wallets whose recovery phrase can be shown
  ///
  /// In en, this message translates to:
  /// **'Choose a wallet'**
  String get desktopRecoveryPhraseChooseWallet;

  /// Desktop sidebar: under a wallet heading for a few seconds when the name typed over it could not be saved; the heading keeps its name
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename the wallet'**
  String get desktopWalletRenameFailed;

  /// Desktop notification on Linux: the action that opens the wallet when the notification is clicked
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get desktopNotificationOpenAction;

  /// Desktop notification title: a send from this computer was confirmed by the chain; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'Sent {amount}'**
  String desktopNotificationSentTitle(String amount);

  /// Desktop notification body: the account the confirmed send came from
  ///
  /// In en, this message translates to:
  /// **'From {account}'**
  String desktopNotificationSentBody(String account);

  /// Desktop notification title: a send from this computer was not seen on the chain within the time the wallet watches for it
  ///
  /// In en, this message translates to:
  /// **'Send not confirmed'**
  String get desktopNotificationSendNotConfirmedTitle;

  /// Desktop notification body: a send not seen on the chain in time; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'{amount} from {account} wasn’t seen on the chain in time. It may have failed, or only be late.'**
  String desktopNotificationSendNotConfirmedBody(String amount, String account);

  /// Desktop notification title: a send from this computer failed
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get desktopNotificationSendFailedTitle;

  /// Desktop notification body: a send that failed; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'{amount} from {account} was not sent.'**
  String desktopNotificationSendFailedBody(String amount, String account);

  /// Desktop notification title: a multisig proposal made on this computer was created on the chain
  ///
  /// In en, this message translates to:
  /// **'Proposal created'**
  String get desktopNotificationProposalCreatedTitle;

  /// Desktop notification body: what the created proposal sends, and from which multisig; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'Send {amount} from {multisig}'**
  String desktopNotificationProposalCreatedBody(String amount, String multisig);

  /// Desktop notification title: a multisig proposal made on this computer was not seen on the chain in time
  ///
  /// In en, this message translates to:
  /// **'Proposal not confirmed'**
  String get desktopNotificationProposalNotConfirmedTitle;

  /// Desktop notification body: a proposal not seen on the chain in time; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'The proposal to send {amount} from {multisig} wasn’t seen on the chain in time.'**
  String desktopNotificationProposalNotConfirmedBody(String amount, String multisig);

  /// Desktop sidebar, read by screen readers: how many accounts a closed wallet holds, as the number on its heading says
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account} other{{count} accounts}}'**
  String desktopWalletAccountCount(int count);

  /// Import: the recovery phrase typed is that of a wallet already in the app; nothing was stored
  ///
  /// In en, this message translates to:
  /// **'This wallet is already in the app'**
  String get importWalletAlreadyAdded;

  /// Desktop: the item that opens the Import Wallet sheet, in the Account menu and the sidebar's Add Account menu
  ///
  /// In en, this message translates to:
  /// **'Import Wallet…'**
  String get desktopMenuImportWallet;

  /// Desktop Import Wallet sheet: a line with a spinner while the wallet is saved and its accounts are found on the chain
  ///
  /// In en, this message translates to:
  /// **'Finding this wallet\'s accounts'**
  String get desktopImportFinding;

  /// Desktop Import Wallet sheet: under the phrase when saving the wallet failed; the phrase stays to try again
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import the wallet'**
  String get desktopImportFailed;

  /// Desktop: a short note by the account name in the top bar after importing a wallet with the sidebar hidden
  ///
  /// In en, this message translates to:
  /// **'Wallet imported'**
  String get desktopImportDone;

  /// Desktop: menu item in Add Account and the Account menu; opens the list that adds and removes multisigs
  ///
  /// In en, this message translates to:
  /// **'Manage Multisigs…'**
  String get desktopMenuManageMultisigs;

  /// Desktop Manage Multisigs sheet: its title
  ///
  /// In en, this message translates to:
  /// **'Manage Multisigs'**
  String get desktopManageMultisigsTitle;

  /// Desktop Manage Multisigs sheet: the sentence under the title
  ///
  /// In en, this message translates to:
  /// **'Multisigs on chain where one of your accounts is a signer. Switching one off removes it from this app only.'**
  String get desktopManageMultisigsLead;

  /// Desktop Manage Multisigs sheet: a moving line while the chain is read
  ///
  /// In en, this message translates to:
  /// **'Finding your multisigs on chain'**
  String get desktopManageMultisigsFinding;

  /// Desktop Manage Multisigs sheet: a row's detail line, e.g. '2 of 3 · you sign as Savings'
  ///
  /// In en, this message translates to:
  /// **'{approvals} · you sign as {name}'**
  String desktopManageMultisigsSignsAs(String approvals, String name);

  /// Desktop: menu item in Add Account and the Account menu; opens the form that creates a multisig
  ///
  /// In en, this message translates to:
  /// **'Create Multisig…'**
  String get desktopMenuCreateMultisig;

  /// Desktop Create Multisig sheet: label of the list of signers
  ///
  /// In en, this message translates to:
  /// **'Signers'**
  String get desktopCreateMultisigSigners;

  /// Desktop Create Multisig form: label of the choice of how many signers must approve
  ///
  /// In en, this message translates to:
  /// **'Approvals needed'**
  String get desktopCreateMultisigApprovalsNeeded;

  /// Desktop Create Multisig review: label of how many signers must approve
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get desktopCreateMultisigApprovals;

  /// Desktop Create Multisig review: how many signers must approve, e.g. '2 of 3 signers'
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} signers'**
  String desktopCreateMultisigApprovalsValue(int count, int total);

  /// Desktop Create Multisig review: label of the address the new multisig will have
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get desktopCreateMultisigAddress;

  /// Desktop Create Multisig review: label of the account that signs and pays for the creation
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get desktopCreateMultisigPaidBy;

  /// Desktop Create Multisig review: label of the chain's fixed fee for creating a multisig
  ///
  /// In en, this message translates to:
  /// **'Creation fee'**
  String get desktopCreateMultisigCreationFee;

  /// Desktop Create Multisig form: what a screen reader and the tooltip call the cross on a signer's row
  ///
  /// In en, this message translates to:
  /// **'Remove signer'**
  String get desktopCreateMultisigRemoveSigner;

  /// Desktop Create Multisig form: the new multisig's address could not be worked out
  ///
  /// In en, this message translates to:
  /// **'Could not work out the new address: {error}'**
  String desktopCreateMultisigPreviewFailed(String error);

  /// Desktop Create Multisig: the account that pays does not hold enough for the fees
  ///
  /// In en, this message translates to:
  /// **'{name} can’t cover what this costs'**
  String desktopCreateMultisigCantAfford(String name);

  /// Desktop Create Multisig review: the system's approval was declined, so nothing was submitted
  ///
  /// In en, this message translates to:
  /// **'Creating this multisig needs your approval'**
  String get desktopCreateMultisigDeclined;

  /// Desktop Create Multisig: the check or the submission failed
  ///
  /// In en, this message translates to:
  /// **'Could not create this multisig: {error}'**
  String desktopCreateMultisigFailed(String error);

  /// Desktop: short note on the active account's sidebar row when a multisig being created was not confirmed in time
  ///
  /// In en, this message translates to:
  /// **'Multisig not confirmed'**
  String get desktopCreateMultisigTimedOut;

  /// Desktop: the item that opens the Connect Cold Wallet sheet, in the Account menu and the sidebar's Add Account menu
  ///
  /// In en, this message translates to:
  /// **'Connect Cold Wallet…'**
  String get desktopMenuConnectColdWallet;

  /// Desktop Connect Cold Wallet sheet: the last step, after showing the account QR code on the device
  ///
  /// In en, this message translates to:
  /// **'Hold it up to this camera'**
  String get desktopColdWalletStepHold;

  /// Desktop Connect Cold Wallet sheet: a line with a spinner while the camera is on
  ///
  /// In en, this message translates to:
  /// **'Looking for a QR code'**
  String get desktopColdWalletLooking;

  /// Desktop Connect Cold Wallet sheet: the camera read a QR code that is not an address
  ///
  /// In en, this message translates to:
  /// **'That QR code isn\'t an account address.'**
  String get desktopColdWalletNotAddress;

  /// Desktop Connect Cold Wallet sheet: the address read is already an account or multisig here
  ///
  /// In en, this message translates to:
  /// **'That account is already in this app.'**
  String get desktopColdWalletAlreadyAdded;

  /// Desktop Connect Cold Wallet sheet: the step showing the address read, before it is added
  ///
  /// In en, this message translates to:
  /// **'Confirm Address'**
  String get desktopColdWalletConfirmTitle;

  /// Desktop Connect Cold Wallet sheet: above the address read
  ///
  /// In en, this message translates to:
  /// **'Check that this matches the address on your cold wallet.'**
  String get desktopColdWalletConfirmBody;

  /// Desktop Connect Cold Wallet sheet: forgets the address read and turns the camera back on
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get desktopColdWalletScanAgain;

  /// Desktop Connect Cold Wallet sheet: adds the address read as a cold wallet account
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get desktopColdWalletConnect;

  /// Desktop Connect Cold Wallet sheet: saving the account failed; the address stays to try again
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect this cold wallet'**
  String get desktopColdWalletSaveFailed;

  /// Desktop camera: this computer has no camera
  ///
  /// In en, this message translates to:
  /// **'No camera found'**
  String get desktopCameraNoneTitle;

  /// Desktop camera: what to do when there is no camera
  ///
  /// In en, this message translates to:
  /// **'Connect a camera to this computer, then try again.'**
  String get desktopCameraNoneBody;

  /// Desktop camera: the system refused this app the camera
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get desktopCameraPermissionTitle;

  /// Desktop camera, macOS: where to allow the camera
  ///
  /// In en, this message translates to:
  /// **'Allow Quantus Wallet under Privacy & Security, Camera.'**
  String get desktopCameraPermissionMac;

  /// Desktop camera, Windows: where to allow the camera
  ///
  /// In en, this message translates to:
  /// **'Allow camera access under Privacy & security, Camera.'**
  String get desktopCameraPermissionWindows;

  /// Desktop camera, Linux: what to check when the camera is refused
  ///
  /// In en, this message translates to:
  /// **'Check that your user is allowed to use the camera.'**
  String get desktopCameraPermissionLinux;

  /// Desktop camera: opens the system's camera privacy settings
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get desktopCameraOpenSettings;

  /// Desktop camera: another app holds the camera
  ///
  /// In en, this message translates to:
  /// **'The camera is in use'**
  String get desktopCameraBusyTitle;

  /// Desktop camera: what to do when another app holds the camera
  ///
  /// In en, this message translates to:
  /// **'Close the other app using it, then try again.'**
  String get desktopCameraBusyBody;

  /// Desktop camera: the camera offers no picture format the app reads
  ///
  /// In en, this message translates to:
  /// **'This camera can\'t be used'**
  String get desktopCameraUnsupportedTitle;

  /// Desktop camera: why the camera cannot be used
  ///
  /// In en, this message translates to:
  /// **'It offers no picture format this app can read.'**
  String get desktopCameraUnsupportedBody;

  /// Desktop camera, Windows N: the system lacks its media components
  ///
  /// In en, this message translates to:
  /// **'Camera support is missing'**
  String get desktopCameraMediaTitle;

  /// Desktop camera, Windows N: what to install
  ///
  /// In en, this message translates to:
  /// **'Install the Media Feature Pack for Windows, then try again.'**
  String get desktopCameraMediaBody;

  /// Desktop camera: it was working and stopped, as when unplugged
  ///
  /// In en, this message translates to:
  /// **'The camera stopped'**
  String get desktopCameraStoppedTitle;

  /// Desktop camera: what to do after it stopped
  ///
  /// In en, this message translates to:
  /// **'Check that it\'s connected, then try again.'**
  String get desktopCameraStoppedBody;

  /// Desktop camera: any other failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t use the camera'**
  String get desktopCameraFailedTitle;

  /// Desktop camera: any other failure, what to do
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with the camera. Try again.'**
  String get desktopCameraFailedBody;

  /// Discord support row title
  ///
  /// In en, this message translates to:
  /// **'Discord'**
  String get settingsHelpDiscord;

  /// Error toast when the entered swap address could not be saved for future swaps
  ///
  /// In en, this message translates to:
  /// **'Could not save the address.'**
  String get swapSaveAddressFailed;

  /// Warning against impostors, shown wherever the app sends someone to the support Discord
  ///
  /// In en, this message translates to:
  /// **'Support will never DM you first or ask for your recovery phrase.'**
  String get commonSupportScamWarning;

  /// Desktop notification body: an Encrypted send that failed part way, which cannot tell whether some of its batches had already paid; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'{amount} from {account} didn’t finish sending. Part of it may have gone through.'**
  String desktopNotificationEncryptedSendFailedBody(String amount, String account);

  /// Desktop swap: the status of a swap whose deposit, made from outside the app, has not been sent yet
  ///
  /// In en, this message translates to:
  /// **'Awaiting deposit'**
  String get desktopSwapAwaitingDeposit;

  /// Desktop swap row: what a swap awaiting its deposit is waiting for
  ///
  /// In en, this message translates to:
  /// **'Waiting for your deposit'**
  String get desktopSwapWaitingForDeposit;

  /// Desktop swap: the time by which a deposit must be sent, after its status
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String desktopSwapUntil(String time);

  /// Desktop swap row: label before what the swap is for
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get desktopSwapFor;

  /// Desktop swap: an amount with its token symbol and the network the token is on
  ///
  /// In en, this message translates to:
  /// **'{amount} on {network}'**
  String desktopSwapAmountOnNetwork(String amount, String network);

  /// Desktop swap panel: what the amount in the headline is swapped for; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'for {amount} on {network}'**
  String desktopSwapForAmountOnNetwork(String amount, String network);

  /// Desktop swap panel: heading over the address a swap pays out at
  ///
  /// In en, this message translates to:
  /// **'Recipient on {network}'**
  String desktopSwapRecipientOn(String network);

  /// Desktop swap: who a swap pays out to, as the last step names it (Sending USDC to the recipient)
  ///
  /// In en, this message translates to:
  /// **'the recipient'**
  String get desktopSwapTheRecipient;

  /// Desktop swap panel: headline of a swap awaiting its deposit; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'Send {amount}'**
  String desktopSwapSendAmount(String amount);

  /// Desktop swap panel: button that drops a swap whose deposit was not sent
  ///
  /// In en, this message translates to:
  /// **'Cancel Swap'**
  String get desktopSwapCancel;

  /// Desktop swap panel: opens the deposit's transaction in the explorer
  ///
  /// In en, this message translates to:
  /// **'View Deposit'**
  String get desktopSwapViewDeposit;

  /// Desktop swap panel: headline of a completed swap; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'{amount} received'**
  String desktopSwapReceived(String amount);

  /// Desktop swap panel: line under a completed swap's headline; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'Your swap of {amount} is complete.'**
  String desktopSwapCompleteBody(String amount);

  /// Desktop swap: attribution to NEAR Intents
  ///
  /// In en, this message translates to:
  /// **'Powered by NEAR Intents'**
  String get desktopSwapPoweredByNearIntents;

  /// Desktop swap sheet: label of the address field for a swap out of QTC; network is the chain the token is paid out on
  ///
  /// In en, this message translates to:
  /// **'Recipient address on {network}'**
  String desktopSwapRecipientAddressOn(String network);

  /// Desktop swap sheet: label of the address field for a swap into QTC, and of that address on the review; network is the chain a refund returns on
  ///
  /// In en, this message translates to:
  /// **'Refund address on {network}'**
  String desktopSwapRefundAddressOn(String network);

  /// Desktop swap sheet: checkbox that puts in the most QTC the account can swap
  ///
  /// In en, this message translates to:
  /// **'Swap the maximum amount'**
  String get desktopSwapMaximum;

  /// Desktop swap sheet: who pays and the most they can put in; amount includes the token symbol
  ///
  /// In en, this message translates to:
  /// **'{account} · {amount} available'**
  String desktopSwapAccountAvailable(String account, String amount);

  /// Desktop swap sheet: shown while the list of tokens is fetched
  ///
  /// In en, this message translates to:
  /// **'Loading tokens'**
  String get desktopSwapLoadingTokens;

  /// Desktop swap sheet: context menu item on a saved address that forgets it
  ///
  /// In en, this message translates to:
  /// **'Remove Saved Address'**
  String get desktopSwapRemoveSavedAddress;

  /// Desktop swap sheet: shown when the saved addresses could not be read, saved to or removed from
  ///
  /// In en, this message translates to:
  /// **'Saved addresses are unavailable: {error}'**
  String desktopSwapSavedAddressesUnavailable(String error);

  /// Desktop Settings, Notifications row: macOS is not letting the app show notifications
  ///
  /// In en, this message translates to:
  /// **'Not allowed in System Settings'**
  String get desktopNotificationNotAllowed;

  /// Desktop Settings, Notifications row: opens the Notifications pane of macOS System Settings
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get desktopNotificationOpenSystemSettings;

  /// Desktop Settings: the Notifications pane of System Settings could not be opened
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open System Settings'**
  String get desktopNotificationOpenSystemSettingsFailed;

  /// Desktop Settings, Notifications row: the system's notifications cannot be used, and why
  ///
  /// In en, this message translates to:
  /// **'Unavailable: {reason}'**
  String desktopNotificationUnavailable(String reason);

  /// Desktop menu bar icon's menu: shows the app's window again
  ///
  /// In en, this message translates to:
  /// **'Open {appName}'**
  String desktopStatusItemOpen(String appName);

  /// Desktop menu bar icon's menu: quits the app
  ///
  /// In en, this message translates to:
  /// **'Quit {appName}'**
  String desktopStatusItemQuit(String appName);

  /// Desktop dialog when the person quits while a send or multisig action is still under way: its title
  ///
  /// In en, this message translates to:
  /// **'A Transaction Is Still Under Way'**
  String get desktopQuitPendingTitle;

  /// Desktop dialog when the person quits with work under way: what quitting now risks and what the app can do instead
  ///
  /// In en, this message translates to:
  /// **'Quitting now could leave it unfinished. The wallet can finish first, then quit on its own.'**
  String get desktopQuitPendingBody;

  /// Desktop dialog when quitting with work under way: hides the window, finishes the work, then quits
  ///
  /// In en, this message translates to:
  /// **'Finish, Then Quit'**
  String get desktopQuitFinishFirst;

  /// Desktop dialog when quitting with work under way: quits at once, even though work is under way
  ///
  /// In en, this message translates to:
  /// **'Quit Now'**
  String get desktopQuitNow;
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
