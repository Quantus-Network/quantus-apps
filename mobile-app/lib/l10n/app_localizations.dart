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

  /// Home banner prompting the user to back up their recovery phrase
  ///
  /// In en, this message translates to:
  /// **'Back up your recovery phrase'**
  String get homeBackupReminder;

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

  /// Add multisig menu row title
  ///
  /// In en, this message translates to:
  /// **'Create Multisig'**
  String get addAccountMenuMultisigTitle;

  /// Add multisig menu row subtitle
  ///
  /// In en, this message translates to:
  /// **'Set up a shared address with multiple signers'**
  String get addAccountMenuMultisigSubtitle;

  /// Discover multisig menu row title
  ///
  /// In en, this message translates to:
  /// **'Discover Multisig'**
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
  /// **'Signer SS58 address'**
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
  /// **'Enter a valid SS58 address.'**
  String get multisigCreateInvalidSigner;

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

  /// Proposal status chip when the current signer has approved
  ///
  /// In en, this message translates to:
  /// **'APPROVED'**
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
  /// **'You\'ve already approved this proposal.'**
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

  /// Approve button on proposal detail
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get multisigApproveButton;

  /// Disabled approve button when user already approved
  ///
  /// In en, this message translates to:
  /// **'Already Approved'**
  String get multisigAlreadyApproved;

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
  /// **'Language, currency, POS mode, notifications'**
  String get settingsPreferencesSubtitle;

  /// Mining rewards row title on settings hub
  ///
  /// In en, this message translates to:
  /// **'Mining Rewards'**
  String get settingsMiningRewards;

  /// Mining rewards row subtitle when data loaded
  ///
  /// In en, this message translates to:
  /// **'{count} blocks mined'**
  String settingsMiningRewardsSubtitle(int count);

  /// Mining rewards row subtitle on error
  ///
  /// In en, this message translates to:
  /// **'Error getting mining rewards'**
  String get settingsMiningRewardsError;

  /// Account type row title on settings hub
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get settingsAccountTypeTitle;

  /// Account type row subtitle on settings hub
  ///
  /// In en, this message translates to:
  /// **'Advanced Account Features'**
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

  /// POS mode row on preferences
  ///
  /// In en, this message translates to:
  /// **'POS Mode'**
  String get settingsPreferencesPosMode;

  /// POS mode row subtitle
  ///
  /// In en, this message translates to:
  /// **'Point of sale features'**
  String get settingsPreferencesPosModeSubtitle;

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

  /// App bar on mining rewards screen
  ///
  /// In en, this message translates to:
  /// **'Mining Rewards'**
  String get settingsMiningTitle;

  /// Redeem button on mining rewards
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get settingsMiningRedeem;

  /// Active mining status label
  ///
  /// In en, this message translates to:
  /// **'Mining'**
  String get settingsMiningStatusMining;

  /// Pending mining status label
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get settingsMiningStatusPending;

  /// Blocks mined stat label
  ///
  /// In en, this message translates to:
  /// **'BLOCKS MINED'**
  String get settingsMiningBlocksMined;

  /// Subtitle under blocks mined count
  ///
  /// In en, this message translates to:
  /// **'blocks across all testnets'**
  String get settingsMiningBlocksAcrossTestnets;

  /// Testnet blocks stat label
  ///
  /// In en, this message translates to:
  /// **'TESTNET BLOCKS'**
  String get settingsMiningStatTestnetBlocks;

  /// Testnet rewards stat label
  ///
  /// In en, this message translates to:
  /// **'TESTNET REWARDS'**
  String get settingsMiningStatTestnetRewards;

  /// Redeemed rewards stat label
  ///
  /// In en, this message translates to:
  /// **'REDEEMED'**
  String get settingsMiningStatRedeemed;

  /// Redeemable rewards stat label
  ///
  /// In en, this message translates to:
  /// **'REDEEMABLE'**
  String get settingsMiningStatRedeemable;

  /// QUAN earned stat label
  ///
  /// In en, this message translates to:
  /// **'QUAN EARNED'**
  String get settingsMiningQuanEarned;

  /// Link to mining telemetry
  ///
  /// In en, this message translates to:
  /// **'View Telemetry ↗'**
  String get settingsMiningViewTelemetry;

  /// Empty state title on mining rewards
  ///
  /// In en, this message translates to:
  /// **'No mining data yet'**
  String get settingsMiningNoDataTitle;

  /// Empty state body on mining rewards
  ///
  /// In en, this message translates to:
  /// **'Set up a Quantus mining node to start earning rewards.'**
  String get settingsMiningNoDataBody;

  /// Link to mining setup guide
  ///
  /// In en, this message translates to:
  /// **'Mining Setup Guide ↗'**
  String get settingsMiningSetupGuide;

  /// Error title on mining rewards screen
  ///
  /// In en, this message translates to:
  /// **'Failed to load mining rewards'**
  String get settingsMiningLoadError;

  /// Error subtitle when connection fails
  ///
  /// In en, this message translates to:
  /// **'Please check your connection'**
  String get settingsMiningCheckConnection;

  /// Blocks label on testnet row
  ///
  /// In en, this message translates to:
  /// **'blocks'**
  String get settingsMiningTestnetBlocks;

  /// Dirac testnet active since date
  ///
  /// In en, this message translates to:
  /// **'Nov 2025'**
  String get settingsMiningDiracSince;

  /// Schrödinger testnet active since date
  ///
  /// In en, this message translates to:
  /// **'Oct 2025'**
  String get settingsMiningSchrodingerSince;

  /// Resonance testnet active since date
  ///
  /// In en, this message translates to:
  /// **'Jul 2025'**
  String get settingsMiningResonanceSince;

  /// App bar on testnet rewards screen
  ///
  /// In en, this message translates to:
  /// **'Testnet Rewards'**
  String get settingsTestnetTitle;

  /// Error title on testnet rewards
  ///
  /// In en, this message translates to:
  /// **'Failed to load testnet rewards'**
  String get settingsTestnetLoadError;

  /// Total blocks headline on testnet rewards
  ///
  /// In en, this message translates to:
  /// **'{count} blocks'**
  String settingsTestnetTotalBlocks(int count);

  /// Description under total blocks
  ///
  /// In en, this message translates to:
  /// **'Total blocks mined across all testnets'**
  String get settingsTestnetTotalDescription;

  /// Breakdown section header
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get settingsTestnetBreakdown;

  /// Blocks count in testnet breakdown row
  ///
  /// In en, this message translates to:
  /// **'{count} blocks'**
  String settingsTestnetRowBlocks(int count);

  /// App bar on help and support screen
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsHelpScreenTitle;

  /// Email support row title
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get settingsHelpEmail;

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

  /// App bar on account type settings
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get settingsAccountTypeScreenTitle;

  /// Intro on account type settings
  ///
  /// In en, this message translates to:
  /// **'Advanced account features are coming soon. These will give you greater control over how transactions are authorised and secured.'**
  String get settingsAccountTypeIntro;

  /// Reversible transactions feature title
  ///
  /// In en, this message translates to:
  /// **'Reversible Transactions'**
  String get settingsAccountTypeReversibleTitle;

  /// Reversible transactions feature subtitle
  ///
  /// In en, this message translates to:
  /// **'Reverse your sends within a time window'**
  String get settingsAccountTypeReversibleSubtitle;

  /// High security account feature title
  ///
  /// In en, this message translates to:
  /// **'High Security Account'**
  String get settingsAccountTypeHighSecurityTitle;

  /// High security account feature subtitle
  ///
  /// In en, this message translates to:
  /// **'Guardian approval required'**
  String get settingsAccountTypeHighSecuritySubtitle;

  /// Multi-signature feature title
  ///
  /// In en, this message translates to:
  /// **'Multi-Signature'**
  String get settingsAccountTypeMultiSigTitle;

  /// Multi-signature feature subtitle
  ///
  /// In en, this message translates to:
  /// **'Multiple approvals required'**
  String get settingsAccountTypeMultiSigSubtitle;

  /// Hardware wallet feature title
  ///
  /// In en, this message translates to:
  /// **'Hardware Wallet'**
  String get settingsAccountTypeHardwareTitle;

  /// Hardware wallet feature subtitle
  ///
  /// In en, this message translates to:
  /// **'Pair a hardware device'**
  String get settingsAccountTypeHardwareSubtitle;

  /// Coming soon badge on account type features
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get settingsAccountTypeComingSoon;

  /// App bar title on swap screens
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swapTitle;

  /// From token section label on swap screen
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get swapFrom;

  /// To token section label on swap screen
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get swapTo;

  /// Refund address field label on swap screen
  ///
  /// In en, this message translates to:
  /// **'Refund Address'**
  String get swapRefundAddress;

  /// Refund address field hint
  ///
  /// In en, this message translates to:
  /// **'{network} Address'**
  String swapRefundAddressHint(String network);

  /// Slippage tolerance label on swap screen
  ///
  /// In en, this message translates to:
  /// **'Slippage Tolerance'**
  String get swapSlippageTolerance;

  /// Exchange rate label on swap screen
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get swapRate;

  /// Get quote button on swap screen
  ///
  /// In en, this message translates to:
  /// **'Get a Quote'**
  String get swapGetQuote;

  /// Exchange rate display
  ///
  /// In en, this message translates to:
  /// **'1 QUAN = {amount} {symbol}'**
  String swapRateLabel(String amount, String symbol);

  /// Exchange rate when amount is zero
  ///
  /// In en, this message translates to:
  /// **'1 QUAN = 0 {symbol}'**
  String swapRateZero(String symbol);

  /// Title on token picker sheet
  ///
  /// In en, this message translates to:
  /// **'Select Token'**
  String get swapTokenPickerTitle;

  /// Error when token list fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load tokens'**
  String get swapTokenPickerLoadError;

  /// Title on review quote sheet
  ///
  /// In en, this message translates to:
  /// **'Review Quote'**
  String get swapReviewTitle;

  /// Total fees row on review quote sheet
  ///
  /// In en, this message translates to:
  /// **'Total fees'**
  String get swapReviewTotalFees;

  /// Total amount row on review quote sheet
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get swapReviewTotalAmount;

  /// Slippage warning on review quote sheet
  ///
  /// In en, this message translates to:
  /// **'You could receive up to \${amount} less based on the {percent}% slippage you set'**
  String swapReviewSlippageWarning(String amount, String percent);

  /// Confirm button on review quote sheet
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get swapReviewConfirm;

  /// Deposit amount label on deposit screen
  ///
  /// In en, this message translates to:
  /// **'Deposit Amount'**
  String get swapDepositAmount;

  /// Toast when deposit amount is copied
  ///
  /// In en, this message translates to:
  /// **'Deposit amount copied to clipboard'**
  String get swapDepositAmountCopied;

  /// Demo warning on deposit screen
  ///
  /// In en, this message translates to:
  /// **'For demo purposes only - do not send funds!'**
  String get swapDepositDemoWarning;

  /// Share QR button on deposit screen
  ///
  /// In en, this message translates to:
  /// **'Share QR'**
  String get swapDepositShareQr;

  /// Share text for deposit details
  ///
  /// In en, this message translates to:
  /// **'Network: {network}\nToken: {token}\nAddress: {address}'**
  String swapDepositShareContent(String network, String token, String address);

  /// Deposit wallet notice on deposit screen
  ///
  /// In en, this message translates to:
  /// **'Use your {symbol} or {network} wallet to deposit funds. Depositing other assets may result in loss of funds.'**
  String swapDepositNotice(String symbol, String network);

  /// Title while swap is processing
  ///
  /// In en, this message translates to:
  /// **'Processing Swap'**
  String get swapDepositProcessingTitle;

  /// Body while swap is processing
  ///
  /// In en, this message translates to:
  /// **'This may take a few minutes...'**
  String get swapDepositProcessingBody;

  /// Title when swap is complete
  ///
  /// In en, this message translates to:
  /// **'Swap Complete'**
  String get swapDepositCompleteTitle;

  /// Body when swap is complete
  ///
  /// In en, this message translates to:
  /// **'Your swap for {amount} QUAN is complete.'**
  String swapDepositCompleteBody(String amount);

  /// Testnet demo banner on deposit screen
  ///
  /// In en, this message translates to:
  /// **'DEMO ONLY - WE ARE STILL ON TESTNET'**
  String get swapDepositTestnetBanner;

  /// Button to confirm funds sent
  ///
  /// In en, this message translates to:
  /// **'I\'ve sent the funds'**
  String get swapDepositSentFunds;

  /// Done button after swap completes
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get swapDepositDone;

  /// Title on refund address picker sheet
  ///
  /// In en, this message translates to:
  /// **'Refund Addresses'**
  String get swapRefundPickerTitle;

  /// Empty state on refund address picker
  ///
  /// In en, this message translates to:
  /// **'No recent refund addresses'**
  String get swapRefundPickerEmpty;

  /// Text for app bar or button label on QR scanner component
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get componentQrScannerTitle;

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

  /// Text for generic loading state
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

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

  /// Section label above the destination address field on redeem
  ///
  /// In en, this message translates to:
  /// **'Redeem To'**
  String get redeemToLabel;

  /// Hint on the redeem destination address field
  ///
  /// In en, this message translates to:
  /// **'Paste a {symbol} Address'**
  String redeemAddressHint(String symbol);

  /// Primary redeem button showing the amount
  ///
  /// In en, this message translates to:
  /// **'Redeem {amount}'**
  String redeemAmountCta(String amount);

  /// Title of the redeem confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Confirm Redeem'**
  String get redeemConfirmTitle;

  /// Amount row label on redeem confirmation
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get redeemConfirmAmount;

  /// Destination row label on redeem confirmation
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get redeemConfirmTo;

  /// Fee row label on redeem confirmation
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get redeemConfirmFee;

  /// Volume fee value on redeem confirmation
  ///
  /// In en, this message translates to:
  /// **'0.1% volume fee'**
  String get redeemFeeValue;

  /// App bar title while a redeem is in progress
  ///
  /// In en, this message translates to:
  /// **'Redeeming...'**
  String get redeemProgressTitle;

  /// App bar title when a redeem finished
  ///
  /// In en, this message translates to:
  /// **'Redeem Complete'**
  String get redeemCompleteTitle;

  /// App bar title when a redeem failed
  ///
  /// In en, this message translates to:
  /// **'Redeem Failed'**
  String get redeemFailedTitle;

  /// Status header label on redeem progress
  ///
  /// In en, this message translates to:
  /// **'REDEEMING'**
  String get redeemingLabel;

  /// Redeem progress step: preparing circuits
  ///
  /// In en, this message translates to:
  /// **'Preparing circuits'**
  String get redeemStepCircuits;

  /// Redeem progress step: fetching transfers
  ///
  /// In en, this message translates to:
  /// **'Fetching transfers'**
  String get redeemStepTransfers;

  /// Redeem progress step: computing nullifiers
  ///
  /// In en, this message translates to:
  /// **'Computing nullifiers'**
  String get redeemStepNullifiers;

  /// Redeem progress step: checking nullifiers
  ///
  /// In en, this message translates to:
  /// **'Checking nullifiers'**
  String get redeemStepCheckNullifiers;

  /// Redeem progress step: generating ZK proofs
  ///
  /// In en, this message translates to:
  /// **'Generating ZK proofs'**
  String get redeemStepProofs;

  /// Redeem progress step: aggregating and submitting
  ///
  /// In en, this message translates to:
  /// **'Aggregating & submitting'**
  String get redeemStepAggregate;

  /// Per-step fetched counter on redeem progress
  ///
  /// In en, this message translates to:
  /// **'{count} fetched'**
  String redeemFetchedCount(int count);

  /// Cancel button on redeem progress
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get redeemCancel;

  /// Retry button on redeem progress
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get redeemRetry;

  /// Close button on redeem progress
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get redeemClose;

  /// Done button on redeem progress
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get redeemDone;

  /// Success banner on redeem progress
  ///
  /// In en, this message translates to:
  /// **'{amount} redeemed in {count} batch(es)'**
  String redeemSuccessBanner(String amount, int count);
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
