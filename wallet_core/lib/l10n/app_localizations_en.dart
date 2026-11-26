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
  String get walletInitErrorMessage => 'Unable to read your recovery phrase from this device.';

  @override
  String get walletInitErrorRemoveWallet => 'Remove Wallet';

  @override
  String get desktopWalletInitErrorRemoveWallet => 'Remove Wallet…';

  @override
  String get walletInitErrorRemoveTitle => 'Remove all wallets from this device?';

  @override
  String get walletInitErrorRemoveBody => 'This cannot be undone.';

  @override
  String get walletInitErrorRemoveConfirm => 'Remove';

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
  String get accountReadyTwoAccountsCreated => 'Two accounts were created for you.';

  @override
  String get accountReadyMainAccountDescription => 'Your main account. Fast, visible on chain.';

  @override
  String get accountReadyEncryptedAccountDescription => 'For private transactions. Shielded, slower.';

  @override
  String get accountReadyGoToWallet => 'Go to Wallet';

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
  String get importWalletScanFailedTitle => 'Account scan failed';

  @override
  String get importWalletScanFailedBody =>
      'We could not reach the network to look for your accounts. Try again now, or skip and the app will scan again the next time it starts.';

  @override
  String get importWalletScanRetry => 'Try again';

  @override
  String get importWalletScanSkip => 'Skip';

  @override
  String homeError(String error) {
    return 'Error: $error';
  }

  @override
  String get homeNoActiveAccount => 'No active account';

  @override
  String get homeErrorLoadingBalance => 'Error loading balance';

  @override
  String get homeBackupReminder => 'Back up your recovery phrase';

  @override
  String get networkStatusOfflineBanner => 'Offline · showing last known balances';

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
  String homeActivityEmptyMessage(String tokenSymbol) {
    return 'Your activity will appear here once you send or receive $tokenSymbol.';
  }

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
  String accountsSheetWallet(int number) {
    return 'Wallet $number';
  }

  @override
  String accountsSheetKeystoneWallet(int number) {
    String _temp0 = intl.Intl.pluralLogic(number, locale: localeName, other: 'Cold Wallet $number', one: 'Cold Wallet');
    return '$_temp0';
  }

  @override
  String get accountsScreenActiveWallet => 'Active Wallet';

  @override
  String accountsScreenAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Accounts', one: '1 Account');
    return '$_temp0';
  }

  @override
  String get walletNameTitle => 'Wallet Name';

  @override
  String get walletNameSubtitle =>
      'Naming your wallets makes it easier to tell their accounts apart. Each wallet has its own encrypted account.';

  @override
  String get walletNameHint => 'Enter a name for your wallet';

  @override
  String get addAccountMenuTitle => 'Add Account';

  @override
  String get addAccountMenuCreateTitle => 'Add Transparent Account';

  @override
  String get addAccountMenuCreateSubtitle => 'Add another public account';

  @override
  String get addAccountMenuMoreTitle => 'Advanced';

  @override
  String get addAccountMenuImportKeystoneTitle => 'Add Cold Wallet';

  @override
  String get addAccountMenuImportKeystoneSubtitle => 'Air-gapped signing via QR code';

  @override
  String get addAccountMenuImportTitle => 'Import Account';

  @override
  String get addAccountMenuImportSubtitle => 'Restore from recovery phrase';

  @override
  String get addAccountMenuMultisigTitle => 'Create Multisig Account';

  @override
  String get addAccountMenuMultisigSubtitle => 'Set up a shared address with multiple signers';

  @override
  String get addAccountMenuDiscoverMultisigTitle => 'Add Multisig Account';

  @override
  String get addAccountMenuDiscoverMultisigSubtitle => 'Find multisigs where your accounts are signers';

  @override
  String get multisigTag => 'MULTISIG';

  @override
  String get multisigProposeTitle => 'Propose';

  @override
  String get multisigAddTitle => 'Create Multisig';

  @override
  String get multisigDiscoverTitle => 'Discover Multisig';

  @override
  String get multisigCreateSubtitle => 'Give this multisig a name you\'ll recognize. You can change it anytime.';

  @override
  String get multisigCreateButton => 'Create';

  @override
  String get multisigCreateCreatingButton => 'Creating';

  @override
  String multisigCreateDefaultName(int number) {
    return 'Multisig $number';
  }

  @override
  String get multisigCreateErrorCouldNotCreate => 'Could not create multisig.';

  @override
  String get multisigCreateReadyToast => 'Multisig added to your accounts.';

  @override
  String get multisigCreateAlreadyExists => 'A multisig with this address already exists on-chain.';

  @override
  String get multisigCreateInsufficientBalance => 'Insufficient balance to cover multisig creation fees.';

  @override
  String get multisigCreateTimeoutToast =>
      'Multisig creation is taking longer than expected. Check the chain or try again.';

  @override
  String get multisigCreateNotSavedToast =>
      'Your multisig was created, but it could not be saved on this device. Restart the app to add it.';

  @override
  String get multisigCreateAuthReason => 'Authenticate to create this multisig';

  @override
  String get multisigCreateSignersLabel => 'SIGNERS';

  @override
  String get multisigCreateSignersSubtitle => 'Add at least one other signer besides yourself.';

  @override
  String get multisigCreateAddSignerHint => 'Signer address';

  @override
  String get multisigCreateAddSignerButton => 'Add Signer';

  @override
  String get multisigCreateDuplicateSigner => 'This signer is already in the list.';

  @override
  String get multisigCreateInvalidSigner => 'Enter a valid signer address.';

  @override
  String get multisigCreateSignerIsMultisig =>
      'This address is a multisig account. A multisig cannot sign, so this signer cannot approve in this wallet. If the remaining members cannot meet the threshold, funds in that multisig may need recovery through the CLI.';

  @override
  String get multisigCreateThresholdLabel => 'THRESHOLD';

  @override
  String multisigCreateThresholdValue(int count, int total) {
    return '$count of $total';
  }

  @override
  String multisigCreateKeystoneAction(int count, int total) {
    return 'Create $count of $total multisig';
  }

  @override
  String get multisigCreatePredictedAddressLabel => 'MULTISIG ADDRESS';

  @override
  String get multisigCreatePredictedAddressPlaceholder => 'Add signers to preview address';

  @override
  String get multisigDone => 'Done';

  @override
  String get multisigAddDiscoveredTitle => 'Discovered for you';

  @override
  String get multisigAddDiscoveredSubtitle => 'Multisigs on chain where one of your accounts is a signer';

  @override
  String get multisigAddButton => 'Add';

  @override
  String get multisigAddedButton => 'Added';

  @override
  String get multisigAddNoneFound => 'No multisigs found.';

  @override
  String multisigAddDiscoverFailed(String error) {
    return 'Could not discover multisigs: $error';
  }

  @override
  String multisigAddFailed(String error) {
    return 'Could not add multisig: $error';
  }

  @override
  String get multisigOpenProposals => 'Open Proposals';

  @override
  String get multisigPastProposals => 'Past Proposals';

  @override
  String get multisigNoOpenProposals => 'No open proposals.';

  @override
  String get multisigNoPastProposals => 'No past proposals.';

  @override
  String multisigLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String multisigProposalToAddress(String address) {
    return 'to $address';
  }

  @override
  String get multisigProposalCallLoading => 'Reading the proposal from the chain…';

  @override
  String get multisigProposalCallUnavailable =>
      'Could not read this proposal from the chain, so there is nothing to approve. Try again when you are back online.';

  @override
  String get multisigProposalInvalid => 'Invalid proposal';

  @override
  String get multisigStatusApproved => 'SIGNED';

  @override
  String get multisigStatusProposed => 'PROPOSED';

  @override
  String get multisigStatusExpired => 'EXPIRED';

  @override
  String get multisigStatusCancelled => 'CANCELLED';

  @override
  String get multisigProposeSelectRecipientTo => 'Transfer to';

  @override
  String multisigProposeSearchHint(String symbol) {
    return 'Enter $symbol Address';
  }

  @override
  String get multisigProposeAmountToLabel => 'TRANSFER TO';

  @override
  String get multisigProposeDepositLabel => 'Deposit:';

  @override
  String get multisigProposeCreationFeeLabel => 'Proposal Fee:';

  @override
  String get multisigProposeDepositRefundableNote => 'refundable';

  @override
  String get multisigProposeMemberTotalLabel => 'TOTAL FROM YOUR ACCOUNT';

  @override
  String get multisigProposeFeeLabel => 'Proposal Fee:';

  @override
  String get multisigProposeFeeFetchFailed => 'Unable to estimate fee';

  @override
  String get multisigProposeFeePayerBalanceLabel => 'Your Balance:';

  @override
  String get multisigProposeFeePayerInsufficient => 'Insufficient Balance for Fee';

  @override
  String get multisigProposeProposerLabel => 'PROPOSER';

  @override
  String get multisigProposeReviewButton => 'Review transfer';

  @override
  String get multisigProposeReviewProposing => 'PROPOSED TRANSFER';

  @override
  String multisigProposeReviewFromName(String name) {
    return 'from $name';
  }

  @override
  String get multisigProposeThresholdLabel => 'THRESHOLD';

  @override
  String get multisigProposeExpiresLabel => 'EXPIRES';

  @override
  String multisigExpiresBlockOnly(int block) {
    return 'Block $block';
  }

  @override
  String get multisigProposeFeeRowLabel => 'PROPOSAL FEE';

  @override
  String get multisigProposeCreateButton => 'Submit proposal';

  @override
  String get multisigProposeAuthReason => 'Authenticate to propose transaction';

  @override
  String get multisigProposeAuthRequired => 'Authentication required';

  @override
  String get multisigProposeSubmitFailed => 'Failed to create proposal';

  @override
  String get multisigProposeTimeoutToast =>
      'Proposal confirmation is taking longer than expected. Check the chain or try again.';

  @override
  String get multisigProposeDoneHeadline => 'Transfer proposal submitted';

  @override
  String get multisigProposeDoneSubline => 'Co-signers must approve before the transfer can execute.';

  @override
  String multisigProposeDoneToChecksum(String checksum) {
    return 'to $checksum';
  }

  @override
  String multisigSignaturesCount(int current, int threshold) {
    return 'Signatures: $current/$threshold';
  }

  @override
  String get multisigProposalTitle => 'Proposal';

  @override
  String multisigProposalLoadFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get multisigProposalNotFound => 'Proposal not found.';

  @override
  String get multisigProposalSignButton => 'Sign';

  @override
  String get multisigProposalSigningSoonNote => 'Signing will be available soon.';

  @override
  String get multisigProposalApprovingLabel => 'Approving…';

  @override
  String get multisigProposalApprovingNote => 'Your approval is being confirmed on-chain.';

  @override
  String get multisigApproveUnavailableNote => 'This proposal can no longer be approved.';

  @override
  String get multisigProposalExpiredNote => 'This proposal has expired.';

  @override
  String get multisigNoSignerHereNote => 'None of this multisig\'s signers is in this wallet.';

  @override
  String get multisigCancelWaitsNote => 'Cancel waits until the approval sent from this device is confirmed.';

  @override
  String get activityTxApproving => 'Approving…';

  @override
  String get activityTxCancelling => 'Cancelling…';

  @override
  String get multisigApprovalTimeoutToast =>
      'Approval confirmation is taking longer than expected. Check the chain or try again.';

  @override
  String get multisigProposalAlreadySignedNote => 'You\'ve already signed this proposal.';

  @override
  String get multisigProposalAlreadyExecutedNote => 'This proposal is already executed.';

  @override
  String get multisigProposalAlreadyCancelledNote => 'This proposal is already cancelled.';

  @override
  String get multisigProposalProposerLabel => 'PROPOSER';

  @override
  String get multisigProposalStatusLabel => 'STATUS';

  @override
  String get multisigProposalDepositLabel => 'DEPOSIT';

  @override
  String get multisigStatusActive => 'ACTIVE';

  @override
  String get multisigStatusExecuted => 'EXECUTED';

  @override
  String get multisigStatusRemoved => 'REMOVED';

  @override
  String get multisigStatusUnknown => 'UNKNOWN';

  @override
  String get activityTxProposal => 'Proposal';

  @override
  String get activityTxProposing => 'Proposing';

  @override
  String get activityTxProposalCreated => 'Proposal created';

  @override
  String get activityTxProposalApproved => 'Proposal approved';

  @override
  String get activityTxProposalExecuted => 'Proposal executed';

  @override
  String get activityTxProposalCancelled => 'Proposal cancelled';

  @override
  String get activityTxProposalRemoved => 'Proposal removed';

  @override
  String get multisigApproveButton => 'Approve';

  @override
  String get multisigAlreadyApproved => 'Already Signed';

  @override
  String get multisigSignerPickerTitle => 'Choose account';

  @override
  String get multisigSignerPickerBody => 'Multiple accounts on this device can sign. Choose which one to approve with.';

  @override
  String get multisigCancelProposalButton => 'Cancel Proposal';

  @override
  String get multisigProposalExpiresLabel => 'EXPIRES';

  @override
  String get multisigProposalAtLabel => 'AT';

  @override
  String get multisigProposalThresholdLabel => 'THRESHOLD';

  @override
  String get multisigProposalApprovalsLabel => 'APPROVALS';

  @override
  String get multisigProposalFeeRowLabel => 'PROPOSAL FEE';

  @override
  String get multisigProposalSignersLabel => 'SIGNERS';

  @override
  String get multisigYouLabel => 'YOU';

  @override
  String get multisigSignerCreatorLabel => 'CREATOR';

  @override
  String get multisigAccountMenuDetails => 'Multisig details';

  @override
  String get multisigAccountMenuDetailsTitle => 'Multisig details';

  @override
  String get multisigAccountMenuDetailsThresholdHint =>
      'This many signer approvals are required to execute a proposal.';

  @override
  String multisigThresholdOf(int count, int total) {
    return '$count of $total';
  }

  @override
  String multisigApprovalsOf(int count, int threshold) {
    return '$count of $threshold';
  }

  @override
  String get multisigApproveConfirmTitle => 'Are you sure?';

  @override
  String get multisigApproveConfirmBody => 'You are about to approve a transfer of';

  @override
  String multisigApproveConfirmTo(String address) {
    return 'to $address';
  }

  @override
  String get multisigApproveConfirmYes => 'Yes, Approve';

  @override
  String get multisigApproveConfirmNo => 'No, Go Back';

  @override
  String get multisigApproveAuthReason => 'Authenticate to approve';

  @override
  String get multisigAuthRequired => 'Authentication required';

  @override
  String get multisigApproveFailed => 'Failed to approve';

  @override
  String get multisigExecuteButton => 'Execute';

  @override
  String get multisigExecuteConfirmTitle => 'Are you sure?';

  @override
  String get multisigExecuteConfirmBody => 'You are about to execute a transfer of';

  @override
  String get multisigExecuteConfirmYes => 'Yes, Execute';

  @override
  String get multisigExecuteAuthReason => 'Authenticate to execute';

  @override
  String get multisigExecuteFailed => 'Failed to execute';

  @override
  String get multisigExecuteUnavailableNote => 'This proposal can no longer be executed.';

  @override
  String get multisigProposalExecutingLabel => 'Executing…';

  @override
  String get multisigProposalExecutingNote => 'Your execution is being confirmed on-chain.';

  @override
  String get activityTxExecuting => 'Executing…';

  @override
  String get multisigExecutionTimeoutToast =>
      'Execution confirmation is taking longer than expected. Check the chain or try again.';

  @override
  String get multisigExecutedByOtherToast => 'Proposal was executed by another signer.';

  @override
  String get multisigFeeEstimateUnavailable => 'Network fee estimate is unavailable.';

  @override
  String get multisigCancelConfirmTitle => 'Cancel Proposal?';

  @override
  String get multisigCancelConfirmBody =>
      'Cancelling refunds your proposal deposit. Other signers will no longer be able to approve.';

  @override
  String get multisigCancelConfirmYes => 'Yes, Cancel Proposal';

  @override
  String get multisigCancelConfirmKeep => 'Keep Proposal';

  @override
  String get multisigCancelAuthReason => 'Authenticate to cancel';

  @override
  String get multisigCancelFailed => 'Failed to cancel';

  @override
  String get multisigProposalCancellingLabel => 'Cancelling…';

  @override
  String get multisigProposalCancellingNote => 'Your cancellation is being confirmed on-chain.';

  @override
  String get multisigCancelTimeoutToast =>
      'Cancellation confirmation is taking longer than expected. Check the chain or try again.';

  @override
  String get multisigApproveTitle => 'Approve';

  @override
  String get multisigApproveDoneExecuted => 'Proposal executed';

  @override
  String get multisigApproveDoneRecorded => 'Approval recorded';

  @override
  String get multisigApproveDoneExecutedSubline => 'Threshold reached — transfer dispatched.';

  @override
  String get multisigApproveDoneRecordedSubline => 'Awaiting more co-signers.';

  @override
  String get createAccountAppBarTitle => 'Account Name';

  @override
  String get createAccountSubtitle => 'Give this account a name you\'ll recognize. You can change it anytime.';

  @override
  String get createAccountButton => 'Create';

  @override
  String get createAccountErrorCouldNotAdd => 'Could not add account.';

  @override
  String get createAccountEncryptedDefaultName => 'Encrypted Account';

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
  String get accountMenuInnerHash => 'Inner Hash';

  @override
  String get accountMenuShowRecoveryPhrase => 'Show Recovery Phrase';

  @override
  String get accountMenuShowAddress => 'Show address';

  @override
  String get accountMenuRename => 'Rename';

  @override
  String get accountMenuDisconnectAccount => 'Disconnect account';

  @override
  String get accountMenuNotFound => 'Account not found';

  @override
  String get accountMenuDone => 'Done';

  @override
  String get accountMenuDisconnect => 'Disconnect';

  @override
  String get accountMenuDisconnectHardwareTitle => 'Disconnect hardware wallet?';

  @override
  String accountMenuDisconnectHardwareMessage(String name) {
    return 'This stops tracking \"$name\" on this device. Your hardware wallet keeps the account, so you can reconnect it anytime.';
  }

  @override
  String get accountMenuDisconnectMultisigTitle => 'Disconnect multisig?';

  @override
  String accountMenuDisconnectMultisigMessage(String name) {
    return 'This stops tracking \"$name\" on this device. The multisig stays on-chain, so you can re-add it anytime.';
  }

  @override
  String get accountMenuDisconnectError => 'Couldn\'t disconnect. Please try again.';

  @override
  String get accountMenuDisconnectAccountTitle => 'Disconnect account?';

  @override
  String accountMenuDisconnectAccountMessage(String name) {
    return 'This stops tracking \"$name\" on this device. Your recovery phrase stays, so you can restore it later.';
  }

  @override
  String accountMenuDisconnectWalletTitle(int number) {
    return 'Disconnect Wallet $number?';
  }

  @override
  String accountMenuDisconnectWalletMessage(String name, int number) {
    return '\"$name\" is the last account in Wallet $number. Disconnecting it removes the entire wallet from this device.';
  }

  @override
  String get accountMenuDisconnectWalletConfirm => 'Disconnect Wallet';

  @override
  String get accountMenuDeleteWalletTitle => 'Are you sure?';

  @override
  String accountMenuDeleteWalletMessage(int number) {
    return 'Wallet $number\'s recovery phrase will be permanently deleted from this device. Make sure it\'s backed up — this can\'t be undone.';
  }

  @override
  String get accountMenuDeleteWalletConfirm => 'Delete Wallet';

  @override
  String get accountDetailsTitle => 'Address Details';

  @override
  String get innerHashTitle => 'Inner Hash';

  @override
  String get innerHashLabel => 'INNER HASH';

  @override
  String get innerHashCopied => 'Inner hash copied';

  @override
  String get innerHashLoadError => 'Couldn\'t load inner hash';

  @override
  String get addKeystoneAppBarTitle => 'Add Cold Wallet';

  @override
  String get addKeystoneIntroTitle => 'Cold Wallet';

  @override
  String get addKeystoneIntroSubtitle =>
      'An air-gapped wallet that talks to this app only through QR codes. Keys never leave the device.';

  @override
  String get addKeystoneConnectButton => 'Connect Cold Wallet';

  @override
  String get addKeystoneConnectTitle => 'Connect Cold Wallet';

  @override
  String get addKeystoneConnectSubtitle => 'Scan your device\'s QR code to connect.';

  @override
  String get addKeystoneOnYourKeystone => 'ON YOUR COLD WALLET';

  @override
  String get addKeystoneStepUnlock => 'Unlock your cold wallet';

  @override
  String get addKeystoneStepSelectQuantus => 'Show your account QR code';

  @override
  String get addKeystoneReadyToScan => 'Ready to Scan';

  @override
  String get invalidAddress => 'Invalid address';

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
  String get sendInputAmountPending => 'Pending:';

  @override
  String get sendInputAmountNetworkFee => 'Transaction Fee:';

  @override
  String get sendInputAmountMax => 'Max';

  @override
  String get sendInputAmountInvalidAmount => 'Please enter a valid amount';

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
  String get sendRegularAccountRequired => 'Switch to a regular account to send';

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
  String get keystoneSignScreenTitle => 'Sign with Cold Wallet';

  @override
  String keystoneSignStep(int current, int total) {
    return 'STEP $current/$total';
  }

  @override
  String get keystoneSignTitle => 'Scan with your cold wallet';

  @override
  String get keystoneSignInstruction => 'Open your cold wallet and scan this QR code to load the transaction.';

  @override
  String get keystoneSignActionLabel => 'ACTION';

  @override
  String get keystoneSignEntireBalance => 'Entire transferable balance';

  @override
  String get keystoneSignYouAreSigning => 'YOU ARE SIGNING';

  @override
  String get keystoneSignNext => 'Continue to Sign';

  @override
  String get keystoneSignCancel => 'Cancel Transaction';

  @override
  String get keystoneSignError => 'Failed to prepare the transaction. Please try again.';

  @override
  String get keystoneVerifyTitle => 'Check your Cold Wallet Screen';

  @override
  String get keystoneVerifyInstruction =>
      'Before approving on your cold wallet, make sure its screen shows exactly this:';

  @override
  String get keystoneVerifyWarning =>
      'If the amount or address on your cold wallet screen is different from what\'s shown here, reject the transaction on your device.';

  @override
  String get keystoneVerifyMismatch => 'It doesn\'t match';

  @override
  String get keystoneScanTitle => 'Scan the signature';

  @override
  String get keystoneScanInstruction =>
      'Your cold wallet is now showing an animated QR. Hold your phone up to it, this takes a moment.';

  @override
  String get keystoneScanReceiving => 'RECEIVING SIGNATURE';

  @override
  String get keystoneScanSubmitting => 'Submitting transaction...';

  @override
  String get keystoneScanError => 'Couldn\'t read the signature. Please try again.';

  @override
  String get keystoneScanExpired =>
      'The transaction expired before it could be submitted. Go back and scan the new QR code with your device.';

  @override
  String get keystoneRejectTitle => 'Don\'t approve this transaction';

  @override
  String get keystoneRejectStep1Title => 'Reject the transaction on your cold wallet.';

  @override
  String get keystoneRejectStep1Body => 'Nothing is signed or sent until you approve there.';

  @override
  String get keystoneRejectStep2Title => 'Don\'t retry from this phone.';

  @override
  String get keystoneRejectStep2Body => 'If it\'s compromised, retrying gives the attacker another chance.';

  @override
  String get keystoneRejectStep3Title => 'Your funds are safe on the cold wallet.';

  @override
  String get keystoneRejectStep3Body => 'Keys never left the device. Move to a trusted phone before sending again.';

  @override
  String get keystoneRejectConfirm => 'I rejected it on the cold wallet';

  @override
  String get sendLogicCantSelfTransfer => 'Can\'t Self Transfer';

  @override
  String get sendLogicEnterAmount => 'Enter Amount';

  @override
  String get sendLogicInvalidAmount => 'Invalid Amount';

  @override
  String sendLogicBelowMinimum(String amount, String tokenSymbol) {
    return 'Minimum is $amount $tokenSymbol';
  }

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
  String get activityTxPrivatelySending => 'Privately Sending';

  @override
  String get activityTxPrivatelyReceiving => 'Privately Receiving';

  @override
  String get activityTxPrivateSent => 'Private Sent';

  @override
  String get activityTxPrivateReceived => 'Private Received';

  @override
  String get activityTxMultisigCreated => 'Multisig created';

  @override
  String get activityTxMultisigCreating => 'Creating multisig';

  @override
  String get activityTxMultisigLabel => 'Multisig';

  @override
  String get activityTxTo => 'To';

  @override
  String get activityTxFrom => 'From';

  @override
  String get activityTxAggregatedBatch => 'Aggregated batch';

  @override
  String get activityDetailAggregatedBatch => 'Aggregated batch, recipient not recorded';

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
  String get activityDetailTitlePrivatelySending => 'Privately Sending';

  @override
  String get activityDetailTitlePrivatelyReceiving => 'Privately Receiving';

  @override
  String get activityDetailTitlePrivateSent => 'Private Sent';

  @override
  String get activityDetailTitlePrivateReceived => 'Private Received';

  @override
  String get activityDetailTitleMultisigCreated => 'Multisig created';

  @override
  String get activityDetailTitleMultisigCreating => 'Creating multisig';

  @override
  String get activityDetailTitleProposalCreated => 'Proposal created';

  @override
  String get activityDetailTitleProposalApproved => 'Proposal approved';

  @override
  String get activityDetailTitleProposalExecuted => 'Proposal executed';

  @override
  String get activityDetailTitleProposalCancelled => 'Proposal cancelled';

  @override
  String get activityDetailTitleCancelling => 'Cancelling proposal';

  @override
  String get activityDetailTitleExecuting => 'Executing proposal';

  @override
  String get activityDetailTitleProposing => 'Proposing';

  @override
  String get activityDetailProposalTransferAmount => 'TRANSFER AMOUNT';

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
  String get activitySenderEncrypted => 'Encrypted';

  @override
  String get activitySenderMiningReward => 'Mining reward';

  @override
  String get activityDetailDate => 'DATE';

  @override
  String get activityDetailNetworkFee => 'NETWORK FEE';

  @override
  String get activityDetailWormholeDetails => 'Wormhole details';

  @override
  String wormholeDetailsBatch(int index, int count) {
    return 'Batch $index of $count';
  }

  @override
  String get wormholeDetailsSent => 'SENT';

  @override
  String get wormholeDetailsChange => 'CHANGE';

  @override
  String get wormholeDetailsInputs => 'INPUTS';

  @override
  String get activityDetailTxHash => 'TX HASH';

  @override
  String get activityDetailTxHashCopied => 'Transaction hash copied to clipboard';

  @override
  String get activityDetailViewExplorer => 'View in Explorer ↗';

  @override
  String get activityDetailMultisigAddress => 'MULTISIG ADDRESS';

  @override
  String get activityDetailMultisigThreshold => 'THRESHOLD';

  @override
  String activityDetailMultisigThresholdValue(int threshold, int total) {
    return '$threshold of $total';
  }

  @override
  String get activityDetailMultisigSignerCount => 'SIGNERS';

  @override
  String get activityDetailMultisigCreator => 'CREATOR';

  @override
  String get activityDetailMultisigCreationFee => 'PALLET FEE';

  @override
  String get activityDetailMultisigDeposit => 'RESERVED DEPOSIT';

  @override
  String get activityDetailMultisigFeePaidByCreator => 'Paid by creator';

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receiveCopy => 'Copy';

  @override
  String receiveErrorLoadingAccount(String error) {
    return 'Error loading account data: $error';
  }

  @override
  String get receiveCopiedMessage => 'Address copied to clipboard';

  @override
  String get receiveYourAddressLabel => 'YOUR ADDRESS';

  @override
  String get receiveCopyAddress => 'Copy Address';

  @override
  String get receiveCheckphraseFootnote => 'Ask the sender to confirm this phrase matches your address.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsWalletTitle => 'Wallet';

  @override
  String get settingsWalletSubtitle => 'Recovery Phrase, Reset Wallet';

  @override
  String get settingsPreferencesTitle => 'Preferences';

  @override
  String get settingsPreferencesSubtitle => 'Language, currency, notifications';

  @override
  String get settingsAccountTypeTitle => 'Add Account';

  @override
  String get settingsAccountTypeSubtitle => 'Manage your accounts';

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
  String get settingsRecoveryAlreadyBackedUp => 'I already backed up my wallet';

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
  String get settingsHelpScreenTitle => 'Help & Support';

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
  String get swapTitle => 'Swap';

  @override
  String get swapPoweredBy => 'Powered By';

  @override
  String get swapFrom => 'From';

  @override
  String get swapTo => 'To';

  @override
  String get swapExternalWallet => 'A wallet you control';

  @override
  String get swapRate => 'Rate';

  @override
  String swapRateLabel(String fromSymbol, String rate, String toSymbol) {
    return '1 $fromSymbol = $rate $toSymbol';
  }

  @override
  String swapRateEstimateLabel(String fromSymbol, String rate, String toSymbol) {
    return '1 $fromSymbol ≈ $rate $toSymbol';
  }

  @override
  String get swapEstimateNotice => 'Estimate at the market price, before fees.';

  @override
  String swapSlippageLabel(String percent) {
    return 'Slippage $percent%';
  }

  @override
  String get swapSlippageTitle => 'Slippage';

  @override
  String get swapSlippageBody =>
      'If the price moves further than this before your swap fills, it is refunded instead. A higher tolerance fills more often but can pay out less.';

  @override
  String get swapSlippageCustom => 'Custom';

  @override
  String swapSlippageCustomMax(String percent) {
    return 'Slippage can be at most $percent%';
  }

  @override
  String get swapAddRecipientAddress => 'Add Recipient Address';

  @override
  String get swapAddRefundAddress => 'Add Refund Address';

  @override
  String get swapRefundTo => 'Refund to';

  @override
  String get swapTokenPickerPayWith => 'Pay with';

  @override
  String get swapTokenPickerReceive => 'Receive';

  @override
  String get swapTokenPickerLoadError => 'Failed to load tokens';

  @override
  String get swapTokenPickerSearchHint => 'Search token or chain';

  @override
  String get swapTokenPickerNoMatch => 'No tokens match your search';

  @override
  String get swapUnavailableTitle => 'Swap unavailable';

  @override
  String get swapDisabledTitle => 'Swap disabled';

  @override
  String get swapUnavailableUnreachable => 'NEAR Intents could not be reached.';

  @override
  String get swapReviewListingChanged => 'The swap\'s terms changed. Review it again.';

  @override
  String swapPreflightBanner(String symbol, String network) {
    return 'Preflight: $symbol on $network stands in for QTC. Real funds move.';
  }

  @override
  String swapQuoteError(String message) {
    return 'Quote failed: $message';
  }

  @override
  String get swapRecipientAddressTitle => 'Recipient Address';

  @override
  String get swapRefundAddressTitle => 'Refund Address';

  @override
  String swapAddressLabel(String symbol) {
    return '$symbol Address';
  }

  @override
  String swapAddressHint(String network) {
    return '$network Address';
  }

  @override
  String swapRecipientAddressNotice(String symbol) {
    return 'Your $symbol will arrive at this address. Double-check it, swaps cannot be reversed.';
  }

  @override
  String swapRefundAddressNotice(String symbol, String network) {
    return 'If the swap cannot complete, your $symbol returns to this address on $network. Double-check it.';
  }

  @override
  String get swapSaveAddress => 'Save for future swaps';

  @override
  String get swapContinue => 'Continue to Swap';

  @override
  String get swapSavedAddressesTitle => 'Saved Addresses';

  @override
  String get swapSavedAddressesEmpty => 'No saved addresses yet';

  @override
  String get swapReviewTitle => 'Review Swap';

  @override
  String get swapYouPay => 'You pay';

  @override
  String get swapYouReceive => 'You receive';

  @override
  String get swapReviewRecipient => 'Recipient';

  @override
  String get swapReviewNetworkFee => 'Network fee';

  @override
  String get swapReviewFeeUnavailable => 'Unavailable';

  @override
  String get swapReviewFeeFailed => 'Could not get the network fee.';

  @override
  String get swapReviewSlippage => 'Slippage allowance';

  @override
  String swapReviewSlippageValue(String amount, String percent) {
    return '$amount ($percent%)';
  }

  @override
  String get swapReviewGuaranteedMinimum => 'Guaranteed minimum';

  @override
  String get swapReviewSwapFee => 'Swap fee';

  @override
  String get swapReviewWithdrawalFee => 'Withdrawal fee';

  @override
  String get swapReviewRefundFee => 'Fee if refunded';

  @override
  String get swapReviewUnusedRefunded =>
      'The payment includes the slippage allowance. Whatever the swap does not use is refunded.';

  @override
  String swapReviewInsufficient(String symbol) {
    return 'Not enough $symbol for this amount plus the network fee.';
  }

  @override
  String get swapReviewPriceMoved => 'The price moved. Check the new amounts and confirm again.';

  @override
  String get swapReviewConfirm => 'Confirm swap';

  @override
  String get swapActivityOverdue => 'Not finished in time';

  @override
  String swapTooManyFollowed(int count) {
    return 'Up to $count swaps can run at once. Wait for one to finish.';
  }

  @override
  String swapActivityAmounts(String amountIn, String amountOut) {
    return '$amountIn → $amountOut';
  }

  @override
  String get swapInProgressTitle => 'Swap In Progress';

  @override
  String get swapYourePaying => 'You\'re paying';

  @override
  String get swapYoureReceiving => 'You\'re receiving';

  @override
  String swapStepDeposited(String symbol) {
    return '$symbol deposited';
  }

  @override
  String swapStepSent(String symbol) {
    return '$symbol sent';
  }

  @override
  String swapStepConfirming(String network) {
    return 'Confirming on $network';
  }

  @override
  String get swapStepSwapping => 'Swapping';

  @override
  String swapStepSending(String symbol, String recipient) {
    return 'Sending $symbol to $recipient';
  }

  @override
  String get swapProgressFooter =>
      'Usually a few minutes. You can leave the app, the swap carries on. · via NEAR Intents';

  @override
  String get swapLiveBrand => 'Swapping';

  @override
  String get swapLiveBrandIdle => 'Swap';

  @override
  String get swapLiveSubmitted => 'Swap submitted';

  @override
  String swapLiveSettling(String network) {
    return 'Settling on $network';
  }

  @override
  String get swapLiveSwapped => 'Swapped';

  @override
  String get swapLiveFrom => 'From';

  @override
  String get swapLiveTo => 'To';

  @override
  String get swapLiveChain => 'Chain';

  @override
  String get swapLiveOpenToCheck => 'Open Quantus to check';

  @override
  String get swapLiveAgo => 'ago';

  @override
  String get swapLiveLeft => 'left';

  @override
  String get swapLiveMinute => 'min';

  @override
  String get swapLiveHour => 'hr';

  @override
  String get swapLiveOverdue => 'Taking longer';

  @override
  String get swapLiveChannel => 'Swap progress';

  @override
  String get swapDetailsTitle => 'Swap Details';

  @override
  String get swapDetailsRecipient => 'Recipient address';

  @override
  String get swapDetailsAmountSent => 'Amount sent';

  @override
  String get swapDetailsExpected => 'Expected';

  @override
  String get swapDetailsDepositAddress => 'Deposit address';

  @override
  String get swapDetailsRequiredDeposit => 'Required deposit';

  @override
  String get swapDetailsDepositWindowEnds => 'Deposit window ends';

  @override
  String get swapDepositTitle => 'Send Your Deposit';

  @override
  String get swapDepositSent => 'I\'ve Sent It';

  @override
  String get swapDetailsTransaction => 'Transaction';

  @override
  String get swapCompleteTitle => 'Swap Complete';

  @override
  String get swapCompleteReceived => 'Received';

  @override
  String get swapCompleteTo => 'To:';

  @override
  String get swapFailedTitle => 'Swap Failed';

  @override
  String get swapRefundedLabel => 'Refunded';

  @override
  String get swapYouPaid => 'You paid';

  @override
  String get swapYouWereReceiving => 'You were receiving';

  @override
  String swapRefundedBody(String amount, String destination, String symbol) {
    return 'The swap could not be completed, so your $amount has been returned to $destination, minus the network fee. The $symbol was never sent.';
  }

  @override
  String swapDepositRefundReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String swapDepositFailedBody(String address) {
    return 'The swap did not complete. Contact support and quote this deposit address: $address';
  }

  @override
  String get swapDepositIncompleteTitle => 'Deposit Too Small';

  @override
  String get swapDepositIncompleteBody =>
      'Less than the quoted amount arrived. It will be refunded to your refund address after the deadline.';

  @override
  String get swapDepositExpiredTitle => 'Quote Expired';

  @override
  String get swapDepositExpiredBody =>
      'No deposit arrived before the deadline. Do not send funds to this address anymore. Get a new quote to try again.';

  @override
  String get swapStartNew => 'Start a New Swap';

  @override
  String get swapDepositAddressCopied => 'Deposit address copied to clipboard';

  @override
  String swapDepositOnly(String symbol, String network) {
    return 'Send $symbol on $network only';
  }

  @override
  String swapDepositDeadline(String time) {
    return 'Send before $time or the quote expires';
  }

  @override
  String get swapDepositMemo => 'Memo';

  @override
  String get swapDepositMemoCopied => 'Deposit memo copied to clipboard';

  @override
  String get swapDepositMemoNotice => 'Include this memo with your deposit. A deposit without it is not processed.';

  @override
  String get swapRequestTimedOut => 'The request timed out';

  @override
  String swapProgressStatusUnavailable(String error) {
    return 'The swap status can\'t be checked right now: $error';
  }

  @override
  String get swapStopTracking => 'Stop tracking swap';

  @override
  String get swapStopTrackingConfirmTitle => 'Stop tracking this swap?';

  @override
  String get swapStopTrackingConfirmBody =>
      'It carries on at NEAR Intents: the funds still arrive, or the deposit is refunded. The wallet just stops following it.';

  @override
  String swapProgressOverdue(String refund) {
    return 'This swap has not finished in time. If it settles later, the funds still arrive, or the deposit is refunded to $refund.';
  }

  @override
  String get componentQrScannerBack => 'Back';

  @override
  String get componentQrScannerTorch => 'Torch';

  @override
  String get componentQrScannerGallery => 'Gallery';

  @override
  String get componentQrScannerCameraUnavailable => 'Camera unavailable';

  @override
  String get componentQrScannerCameraDenied => 'Allow camera access in Settings to scan.';

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
  String get componentAmountApproximatePrefix => '≈';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCanceling => 'Canceling...';

  @override
  String commonAmountBalance(String balance, String symbol) {
    return '$balance $symbol';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSave => 'Save';

  @override
  String commonPercent(String percent) {
    return '$percent%';
  }

  @override
  String get commonContactSupport => 'Contact Support';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get redeemCancel => 'Cancel';

  @override
  String get redeemClose => 'Close';

  @override
  String get encryptedSendFeeLabel => 'Transaction Fee';

  @override
  String encryptedSendAmountStep(String tokenSymbol) {
    return 'Use steps of 0.01 $tokenSymbol';
  }

  @override
  String encryptedSendInsufficientWithPending(String amount, String tokenSymbol) {
    return 'Insufficient Balance ($amount $tokenSymbol pending)';
  }

  @override
  String encryptedSendMinimum(String tokenSymbol) {
    return 'Encrypted sends must move at least 0.1 $tokenSymbol';
  }

  @override
  String get encryptedSendProgressTitle => 'Private Send';

  @override
  String get encryptedSendFailedTitle => 'Send Failed';

  @override
  String get encryptedSendCancelledTitle => 'Send Cancelled';

  @override
  String get encryptedSendingLabel => 'SENDING PRIVATELY';

  @override
  String get encryptedSendStepPreparing => 'Preparing';

  @override
  String get encryptedSendStepGathering => 'Gathering funds';

  @override
  String get encryptedSendStepSecuring => 'Securing transaction';

  @override
  String get encryptedSendStepGenerating => 'Generate proofs';

  @override
  String get encryptedSendStepProving => 'Building privacy proof';

  @override
  String get encryptedSendStepSubmitting => 'Submitting to chain';

  @override
  String get encryptedSendProgressFooter =>
      'Privacy takes a moment. Please keep the app open until the transaction completes.';

  @override
  String encryptedSendCancelledPartial(String amount) {
    return '$amount was already sent before cancelling. The rest remains in your account.';
  }

  @override
  String get encryptedSendFundsSafeLabel => 'Your funds are safe';

  @override
  String encryptedSendFundsSafeCaption(String account) {
    return 'Still in $account. Nothing left your wallet.';
  }

  @override
  String get privateSendTitle => 'Private Send';

  @override
  String get privateSendSubtitle => 'Hides the link between your account and the recipient';

  @override
  String get encryptedSendNearIntentsTitle => 'NEAR Intents address detected';

  @override
  String get encryptedSendNearIntentsDescription =>
      'This is a single-use NEAR Intents deposit address. Use a transparent account to send to NEAR Intents.';

  @override
  String get encryptedSendNearIntentsButton => 'Can\'t Send to NEAR Intents';

  @override
  String get sendRecipientChecking => 'Verifying Address…';

  @override
  String get sendRecipientCheckFailed => 'Couldn\'t Verify Address';

  @override
  String get sendRecipientCheckFailedMessage => 'Couldn\'t verify the address. Check your connection and try again.';

  @override
  String get encryptedSendPlanStale =>
      'Your encrypted balance changed while reviewing. Please go back and enter the amount again.';

  @override
  String get mainnetMigrationTitle => 'Quantus is live on *mainnet*.';

  @override
  String get mainnetMigrationChecking => 'Testnet has shut down. Checking what that means for this wallet.';

  @override
  String get mainnetMigrationReadingHistory => 'Reading testnet history';

  @override
  String mainnetMigrationBlocksMinedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString';
  }

  @override
  String get mainnetMigrationBlocksMined => 'Blocks mined on testnet';

  @override
  String get mainnetMigrationMinerTitle => 'Keep this wallet.';

  @override
  String get mainnetMigrationMinerBody =>
      'Your rewards are safe. They\'re tied to it and arrive after launch. Your balance starts at zero because rewards are based on blocks mined, not on your testnet balance.';

  @override
  String get mainnetMigrationNotMinedTitle => 'Nothing carried over.';

  @override
  String mainnetMigrationNotMinedBody(String tokenSymbol) {
    return 'Your testnet balance stayed on testnet. Those coins were only ever for testing, so this wallet starts at zero $tokenSymbol.';
  }

  @override
  String get mainnetMigrationUnreachableBadge => 'Couldn\'t check';

  @override
  String get mainnetMigrationUnreachableTitle => 'We couldn\'t check this wallet.';

  @override
  String mainnetMigrationUnreachableBody(String tokenSymbol) {
    return 'Testnet was unreachable, so we don\'t know yet whether you mined. Your balance starts at zero $tokenSymbol either way.';
  }

  @override
  String get mainnetMigrationUnreachableRewards =>
      'If you mined, your rewards are safe. They stay tied to this wallet whether we can check today or not.';

  @override
  String get mainnetMigrationKeepWallet => 'Keep this wallet';

  @override
  String get mainnetMigrationCreateWallet => 'Create a new wallet';

  @override
  String get mainnetMigrationCreateDialogTitle => 'Create a new wallet?';

  @override
  String get mainnetMigrationCreateDialogBody =>
      'You\'ll get a new secret phrase to write down and store safely. This wallet stays on the device.';

  @override
  String get mainnetMigrationCreateDialogUncheckedTitle => 'We couldn\'t check this wallet';

  @override
  String get mainnetMigrationCreateDialogUncheckedBody => 'So we don\'t know whether you mined on testnet.';

  @override
  String get mainnetMigrationCreateDialogUncheckedAdvice =>
      'If you mined, your rewards are tied to this wallet. We\'d suggest keeping it and trying again later.';

  @override
  String get mainnetMigrationCreateDialogConfirm => 'Create new wallet';

  @override
  String get mainnetMigrationCreateDialogCancel => 'Keep my wallet';

  @override
  String get mainnetMigrationAllSetBadge => 'Mainnet';

  @override
  String get mainnetMigrationAllSetTitle => 'You\'re all set.';

  @override
  String mainnetMigrationAllSetBody(String tokenSymbol) {
    return 'Everything from here is real money. Add some $tokenSymbol whenever you\'re ready.';
  }

  @override
  String mainnetMigrationGetTokens(String tokenSymbol) {
    return 'Get $tokenSymbol';
  }

  @override
  String get mainnetMigrationGoToWallet => 'Go to wallet';

  @override
  String mainnetMigrationSaveFailed(String error) {
    return 'Could not save your choice: $error';
  }

  @override
  String get settingsMiningRewards => 'Mining Rewards';

  @override
  String get settingsMiningRewardsSubtitle => 'Claim your testnet mining rewards';

  @override
  String miningRewardsHeroTitle(String symbol) {
    return 'Testnet mining paid out in $symbol.';
  }

  @override
  String get miningRewardsHeroBody =>
      'Rewards are based on the blocks you mined on Resonance, Schrödinger, Dirac, and Planck testnets. Amounts are already set.';

  @override
  String get settingsSelectWalletSection => 'Wallets on the device';

  @override
  String miningRewardsCheckingAddresses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Checking $count addresses',
      one: 'Checking 1 address',
    );
    return '$_temp0';
  }

  @override
  String miningRewardsProgressOf(int total) {
    return 'of $total';
  }

  @override
  String get miningRewardsTotalRewards => 'Total rewards';

  @override
  String miningRewardsBlocks(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString blocks', one: '1 block');
    return '$_temp0';
  }

  @override
  String get miningRewardsNotMined => 'Not mined';

  @override
  String get miningRewardsSheetBlocksMined => 'Blocks mined';

  @override
  String get miningRewardsSheetReward => 'Reward';

  @override
  String get miningRewardsNoMiningTitle => 'No mining on this wallet';

  @override
  String get miningRewardsNoMiningBody1 =>
      'We checked your addresses against Resonance, Schrödinger, Dirac and Planck, and found no blocks.';

  @override
  String get miningRewardsNoMiningBody2 => 'If you mined with a different wallet, go back and choose it.';

  @override
  String get miningRewardsTryAnotherWallet => 'Try another wallet';

  @override
  String get miningRewardsPayToIntro => 'Enter the address we should send the rewards to';

  @override
  String get miningRewardsUseAnotherAddress => 'Use Another Address';

  @override
  String get miningRewardsAnotherAddressTitle => 'Another Address';

  @override
  String get miningRewardsDestinationLabel => 'Destination';

  @override
  String miningRewardsPasteAddressHint(String symbol) {
    return 'Paste $symbol Address';
  }

  @override
  String get miningRewardsAddressAdvice =>
      'Use an address you control. Rewards sent to an address you don\'t own can\'t be recovered.';

  @override
  String miningRewardsAddressInvalid(String symbol) {
    return 'This isn\'t a valid $symbol address. Check the last few characters.';
  }

  @override
  String get miningRewardsConfirmTitle => 'Confirm Destination';

  @override
  String get miningRewardsClaimingLabel => 'Claiming';

  @override
  String get miningRewardsAmountLabel => 'Amount';

  @override
  String get miningRewardsPayoutLabel => 'Payout';

  @override
  String get miningRewardsPayoutWindow => 'Within a week';

  @override
  String get miningRewardsChangeDetails => 'Change Details';

  @override
  String get miningRewardsSubmitFailedTitle => 'Couldn\'t submit right now';

  @override
  String get miningRewardsSubmitFailedBody1 => 'Something went wrong reaching the network.';

  @override
  String get miningRewardsSubmitFailedBody2 =>
      'Your rewards are safe. Nothing expires and there is no deadline to claim.';

  @override
  String get miningRewardsSubmitPartialTitle => 'Some claims have been submitted';

  @override
  String get miningRewardsSubmitPartialBody => 'Please try again to submit the rest.';

  @override
  String get miningRewardsSubmittedAll => 'All claims have been submitted.';

  @override
  String miningRewardsSubmittedPayingTo(String destination) {
    return 'Paying to $destination.';
  }

  @override
  String get miningRewardsSubmittedNote => 'Payouts go out within a week. Nothing else to do.';

  @override
  String miningRewardsClaimedOn(String date) {
    return 'Claimed $date';
  }

  @override
  String get miningRewardsPayingTo => 'Paying To';

  @override
  String get miningRewardsCheckAnotherWallet => 'Check another wallet';

  @override
  String get miningRewardsWalletsLabel => 'Wallets';

  @override
  String get miningRewardsClaimedTag => 'Claimed';

  @override
  String get miningRewardsNotClaimed => 'Not claimed yet';

  @override
  String get miningRewardsCheckEligibility => 'Check eligibility';

  @override
  String get miningRewardsNotClaimable => 'Claim not available yet';

  @override
  String get miningRewardsCheckFailed => 'Check failed, tap to retry';

  @override
  String get miningRewardsClaim => 'Claim';

  @override
  String get miningRewardsSubmitClaims => 'Submit Claim';

  @override
  String get desktopMenuSettings => 'Settings…';

  @override
  String get desktopMenuFile => 'File';

  @override
  String get desktopMenuCloseWindow => 'Close Window';

  @override
  String get desktopMenuAccount => 'Account';

  @override
  String get desktopMenuNewAccount => 'New Account';

  @override
  String get desktopMenuView => 'View';

  @override
  String get desktopMenuHideSidebar => 'Hide Sidebar';

  @override
  String get desktopMenuShowSidebar => 'Show Sidebar';

  @override
  String get desktopMenuNextSidebarItem => 'Next Sidebar Item';

  @override
  String get desktopMenuPreviousSidebarItem => 'Previous Sidebar Item';

  @override
  String get desktopMenuRefresh => 'Refresh';

  @override
  String get desktopMenuWindow => 'Window';

  @override
  String get desktopBootProtocol => '> QUANTUS PROTOCOL v1.0.0-gm';

  @override
  String desktopBootNistModule(String status) {
    return '> NIST FIPS 204 MODULE LOADED $status';
  }

  @override
  String desktopBootInitializing(String scheme) {
    return '> INITIALIZING $scheme...';
  }

  @override
  String desktopBootSignatureScheme(String status) {
    return '> POST-QUANTUM SIGNATURE SCHEME $status';
  }

  @override
  String desktopBootZkEngine(String status) {
    return '> RECURSIVE ZK PROOF ENGINE $status';
  }

  @override
  String desktopBootChladni(String status) {
    return '> CHLADNI FIELD VISUALIZER $status';
  }

  @override
  String get desktopBootStatusOk => '[OK]';

  @override
  String get desktopBootStatusActive => 'ACTIVE';

  @override
  String get desktopBootStatusReady => 'READY';

  @override
  String get desktopBootStatusLoading => 'LOADING';

  @override
  String get desktopWaveModeLabel => 'WAVE MODE (m,n)';

  @override
  String get desktopWaveModeHint => 'MOVE CURSOR TO SHIFT FREQUENCY';

  @override
  String get desktopWelcomeEyebrow => 'Quantum-Secure Encrypted Money';

  @override
  String get desktopWelcomeTitleLine1 => 'Money quantum';

  @override
  String get desktopWelcomeTitleLine2 => 'computers can’t break.';

  @override
  String get desktopWelcomeBody => 'Create a new wallet, or import one you already have.';

  @override
  String get desktopBalanceLabel => 'Balance';

  @override
  String get desktopImportHeadline => 'Restore your wallet.';

  @override
  String get desktopImportTipWordCount => '12 or 24 words';

  @override
  String get desktopImportTipSpaces => 'Separated by spaces';

  @override
  String get desktopImportTipPaste => 'Paste the whole phrase at once';

  @override
  String get desktopImportPhraseLabel => 'Recovery phrase';

  @override
  String get desktopImportPaste => 'Paste';

  @override
  String desktopImportWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count words', one: '1 word');
    return '$_temp0';
  }

  @override
  String get desktopWalletReadyHeadline => 'Your wallet is ready.';

  @override
  String desktopWalletReadyBody(String account, String encrypted) {
    return '$account is transparent: fast, and visible on chain. The $encrypted is for private transactions, and slower.';
  }

  @override
  String get desktopReceiveDepositAddressLabel => 'Deposit address';

  @override
  String get desktopReceiveEncryptedNotice =>
      'A new address once this one has been paid, so your deposits can’t be linked to each other.';

  @override
  String get desktopCopied => 'Copied';

  @override
  String get desktopApprovalNeedsMacPassword => 'Set up a login password for this Mac to use this.';

  @override
  String get desktopApprovalNeedsWindowsHello => 'Set up Windows Hello to use this.';

  @override
  String get desktopApprovalNeedsLinuxService =>
      'Install Quantus Wallet’s PAM service (/etc/pam.d/quantus-wallet) to use this.';

  @override
  String get desktopApprovalLoginAsksMore =>
      'This computer’s login asks for more than a password, which Quantus Wallet can’t answer yet.';

  @override
  String get desktopPasswordPromptTitle => 'Enter your login password';

  @override
  String get desktopPasswordPromptHint => 'Password';

  @override
  String get desktopPasswordPromptConfirm => 'Confirm';

  @override
  String get desktopPasswordPromptWrong => 'That password is not right. Try again.';

  @override
  String desktopApprovalFailed(String error) {
    return 'Couldn’t ask for approval: $error';
  }

  @override
  String get desktopRecoveryPhraseEyebrow => 'Before you look';

  @override
  String get desktopResetEyebrow => 'Cannot be undone';

  @override
  String get desktopRecoveryPhraseHide => 'Hide';

  @override
  String get desktopRecoveryPhraseShow => 'Show';

  @override
  String get desktopRecoveryPhraseUnreadable => 'This wallet’s recovery phrase could not be read.';

  @override
  String get desktopRecoveryPhraseCopyFailed => 'Couldn’t copy the recovery phrase.';

  @override
  String get desktopSendAddressHint => 'Quantus address';

  @override
  String get desktopSendAddressInvalid => 'This is not a Quantus address.';

  @override
  String get desktopSendAddressSelf => 'You can’t send to the account you’re sending from.';

  @override
  String get desktopSendAvailable => 'Available';

  @override
  String desktopSendAmountTooMuch(String amount) {
    return 'More than the $amount you can send.';
  }

  @override
  String get desktopSendMaximum => 'Send the maximum amount';

  @override
  String get desktopSendTransactionFee => 'Transaction fee';

  @override
  String get desktopSendStatusStopped => '[STOPPED]';

  @override
  String get desktopSendStatusFailed => '[FAILED]';

  @override
  String get desktopSendReview => 'Review';

  @override
  String get desktopSendYouPaid => 'You paid';

  @override
  String get desktopSendSubmitted => 'Submitted';

  @override
  String get desktopViewInExplorer => 'View in Explorer';

  @override
  String desktopSendTransactionOf(int index, int count) {
    return 'Transaction $index of $count';
  }

  @override
  String get desktopAccountSwitchFailedTitle => 'Could not switch account';

  @override
  String desktopAccountSwitchFailedMessage(String account, String error) {
    return '$account could not be made the active account: $error';
  }

  @override
  String get settingsKeyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get settingsKeyboardShortcutsSubtitle => 'Change the keys that open and move around the wallet';

  @override
  String get desktopShortcutsToggleSidebar => 'Show or Hide Sidebar';

  @override
  String get desktopShortcutsAccounts => 'Go to account 1 to 9';

  @override
  String get desktopShortcutsNone => 'None';

  @override
  String get desktopShortcutsRecording => 'Type shortcut…';

  @override
  String get desktopShortcutsRecordingHint => 'Press the new keys. Esc cancels; Delete removes the shortcut.';

  @override
  String get desktopShortcutsNeedsModifierMac => 'Hold Command, Option or Control with the key.';

  @override
  String get desktopShortcutsNeedsModifierPc => 'Hold Ctrl or Alt with the key.';

  @override
  String get desktopShortcutsSystemKey => 'Shortcuts with the Windows or Super key belong to the system.';

  @override
  String get desktopShortcutsKeyNotForMenuBar => 'The menu bar cannot use that key. Press other keys.';

  @override
  String get desktopShortcutsFixedNote => 'Settings, Close Window and Quit keep the system\'s keys.';

  @override
  String get desktopShortcutsRestoreDefaults => 'Restore Defaults';

  @override
  String get desktopShortcutsUnreadable => 'Your saved shortcuts could not be read, so the defaults are in use.';

  @override
  String get desktopSystemQuit => 'Quit';

  @override
  String get desktopSystemHide => 'Hide';

  @override
  String get desktopSystemHideOthers => 'Hide Others';

  @override
  String get desktopSystemMinimize => 'Minimize';

  @override
  String get desktopSystemFullScreen => 'Full Screen';

  @override
  String get desktopSystemCut => 'Cut';

  @override
  String get desktopSystemCopy => 'Copy';

  @override
  String get desktopSystemPaste => 'Paste';

  @override
  String get desktopSystemSelectAll => 'Select All';

  @override
  String get desktopSystemUndo => 'Undo';

  @override
  String get desktopSystemRedo => 'Redo';

  @override
  String desktopShortcutsUsedBy(String command) {
    return 'That shortcut is already used by $command. Press other keys.';
  }

  @override
  String desktopShortcutsKeptFor(String command) {
    return 'That shortcut is kept for $command. Press other keys.';
  }

  @override
  String desktopShortcutsModifierUsedBy(String command) {
    return 'Those keys would clash with $command.';
  }

  @override
  String desktopShortcutsSaveFailed(String error) {
    return 'The shortcut could not be saved: $error';
  }

  @override
  String get desktopProposeCost => 'Proposal cost';

  @override
  String desktopProposeCostPaidBy(String cost) {
    return '$cost, paid by';
  }

  @override
  String desktopProposeCostNotCovered(String account) {
    return '$account does not hold enough to pay the proposal cost.';
  }

  @override
  String get desktopProposeMaximum => 'Propose the maximum amount';

  @override
  String get desktopProposeProposing => 'Proposing';

  @override
  String get desktopProposeProposedBy => 'Proposed by';

  @override
  String get desktopProposeApprovalsNeeded => 'Approvals needed';

  @override
  String get desktopProposeApprovals => 'Approvals';

  @override
  String desktopProposeCountOf(int count, int total) {
    return '$count of $total';
  }

  @override
  String get desktopProposeExpires => 'Expires';

  @override
  String get desktopProposeDeposit => 'Deposit';

  @override
  String get desktopProposeFee => 'Proposal fee';

  @override
  String get desktopProposePays => 'pays';

  @override
  String get desktopProposePaid => 'paid';

  @override
  String get desktopProposeSubmit => 'Submit Proposal';

  @override
  String desktopProposeProposed(String amount) {
    return '$amount proposed';
  }

  @override
  String get desktopProposeConfirming => 'Confirming';

  @override
  String get desktopProposeNotConfirmed => 'Not confirmed';

  @override
  String desktopProposeProposingAmount(String amount) {
    return 'Proposing $amount';
  }

  @override
  String get desktopProposeWaiting => 'Waiting for the network to create the proposal.';

  @override
  String get desktopProposalApproved => 'Approved';

  @override
  String get desktopProposalExpired => 'Expired';

  @override
  String get desktopProposalUnreadable =>
      'This wallet can\'t read what this proposal would do, so it can\'t be approved or executed here.';

  @override
  String get desktopProposalApproving => 'Approving';

  @override
  String get desktopProposalExecuting => 'Executing';

  @override
  String get desktopProposalCancelling => 'Cancelling';

  @override
  String get desktopProposalSignsAs => 'Signs as';

  @override
  String get desktopProposalSignedAs => 'Signed as';

  @override
  String get desktopProposalDepositRefunded => 'Deposit refunded';

  @override
  String desktopProposalApprovalsChange(String before, String after) {
    return '$before → $after';
  }

  @override
  String desktopProposalKeystoneApprove(String name) {
    return '$name signs with a Keystone, which this app cannot sign with yet. Approve on your phone.';
  }

  @override
  String desktopProposalKeystoneExecute(String name) {
    return '$name signs with a Keystone, which this app cannot sign with yet. Execute on your phone.';
  }

  @override
  String desktopProposalKeystoneCancel(String name) {
    return '$name signs with a Keystone, which this app cannot sign with yet. Cancel on your phone.';
  }

  @override
  String desktopProposalApprovingTitle(String what) {
    return 'Approving $what';
  }

  @override
  String desktopProposalApprovedTitle(String what) {
    return '$what approved';
  }

  @override
  String desktopProposalExecutingTitle(String what) {
    return 'Executing $what';
  }

  @override
  String desktopProposalExecutedTitle(String what) {
    return '$what executed';
  }

  @override
  String desktopProposalCancellingTitle(String what) {
    return 'Cancelling $what';
  }

  @override
  String get desktopProposalCancelledTitle => 'Proposal cancelled';

  @override
  String get desktopProposalApprovalWaiting => 'Waiting for the network to record your approval.';

  @override
  String get desktopProposalExecutionWaiting => 'Waiting for the network to record your execution.';

  @override
  String get desktopProposalCancellationWaiting => 'Waiting for the network to record your cancellation.';

  @override
  String get desktopProposalReadyToExecute => 'It has every approval it needs, and can be executed.';

  @override
  String desktopProposalApprovalsNeeded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more approvals needed.',
      one: '1 more approval needed.',
    );
    return '$_temp0';
  }

  @override
  String get desktopProposalExecutedDone => 'The proposal has run.';

  @override
  String get desktopProposalCancelledDone => 'Your deposit is refunded.';

  @override
  String get desktopProposalExecutedByAnother => 'Executed by another signer';

  @override
  String get desktopProposalExecutedByAnotherBody =>
      'Another signer executed this proposal first, so your transaction did not go through. Its network fee was still paid.';

  @override
  String get desktopFooterMainnet => 'Mainnet';

  @override
  String get desktopFooterTestnet => 'Testnet';

  @override
  String get desktopFooterOffline => 'Offline';

  @override
  String get desktopFooterSyncing => 'Syncing';

  @override
  String get desktopFooterSyncedJustNow => 'Synced just now';

  @override
  String desktopFooterSyncedMinutesAgo(int minutes) {
    return 'Synced ${minutes}m ago';
  }

  @override
  String desktopFooterSyncedHoursAgo(int hours) {
    return 'Synced ${hours}h ago';
  }

  @override
  String desktopFooterSyncedDaysAgo(int days) {
    return 'Synced ${days}d ago';
  }

  @override
  String get desktopFooterSyncFailed => 'Couldn\'t sync';

  @override
  String desktopFooterBlock(String number) {
    return 'Block $number';
  }

  @override
  String desktopFooterVersion(String version) {
    return 'Quantus Wallet $version';
  }

  @override
  String get desktopActivityInProgress => 'In progress';

  @override
  String get desktopActivityLoadFailed => 'Couldn\'t load the activity';

  @override
  String get desktopActivityRefreshFailed => 'Couldn\'t refresh the activity';

  @override
  String get desktopMarksAddress => 'Address';

  @override
  String desktopMarksInProgress(int count) {
    return '$count in progress';
  }

  @override
  String desktopMarksWaitingForSignature(int count) {
    return '$count waiting for your signature';
  }

  @override
  String desktopActivityRunsIn(String time) {
    return 'in $time';
  }

  @override
  String get desktopActivityTransaction => 'Transaction';

  @override
  String get desktopActivityAmount => 'Amount';

  @override
  String get desktopActivityThreshold => 'Threshold';

  @override
  String get desktopActivitySigners => 'Signers';

  @override
  String get desktopActivityCreatedBy => 'Created by';

  @override
  String get desktopActivityCreationFee => 'Multisig fee';

  @override
  String get desktopAccountGetInfo => 'Get Info';

  @override
  String get desktopAccountCopyAddress => 'Copy Address';

  @override
  String get desktopAccountCopyInnerHash => 'Copy Inner Hash';

  @override
  String get desktopAccountRename => 'Rename…';

  @override
  String get desktopAccountShowRecoveryPhrase => 'Show Recovery Phrase…';

  @override
  String get desktopAccountShowSigners => 'Show Signers…';

  @override
  String get desktopAccountDisconnectAccount => 'Disconnect Account…';

  @override
  String get desktopAccountDisconnectHardware => 'Disconnect Hardware Account…';

  @override
  String get desktopAccountDisconnectMultisig => 'Disconnect Multisig…';

  @override
  String get desktopAccountAddressCopied => 'Address copied';

  @override
  String get desktopAccountInnerHashCopied => 'Inner hash copied';

  @override
  String desktopAccountCopyFailed(String error) {
    return 'Couldn’t copy: $error';
  }

  @override
  String get desktopAccountInfoTitle => 'Account Info';

  @override
  String get desktopMultisigInfoTitle => 'Multisig Info';

  @override
  String get desktopAccountInfoAccount => 'Account';

  @override
  String get desktopAccountInfoMultisig => 'Multisig';

  @override
  String get desktopAccountInfoSigners => 'Signers';

  @override
  String get desktopAccountInfoThisDevice => 'This device';

  @override
  String get desktopAccountInfoMiningRewards => 'Mining rewards';

  @override
  String get desktopAccountInfoName => 'Name';

  @override
  String get desktopAccountInfoNameSubtitle => 'Shown only in this app';

  @override
  String get desktopAccountInfoThreshold => 'Threshold';

  @override
  String get desktopAccountInfoThresholdSubtitle => 'Signatures a proposal needs before it can run';

  @override
  String desktopAccountInfoPhraseSubtitle(String wallet) {
    return 'The 24 words of $wallet, which this account is in';
  }

  @override
  String get desktopAccountInfoInnerHash => 'Inner Hash';

  @override
  String get desktopAccountInfoInnerHashCaption =>
      'Give it to your miner as --rewards-inner-hash, and block rewards land in this account.';

  @override
  String get desktopAccountInfoCreator => 'Creator';

  @override
  String get desktopAccountInfoYou => 'You';

  @override
  String get desktopAccountInfoDisconnectAccount => 'Disconnect Account';

  @override
  String desktopAccountInfoDisconnectAccountSubtitle(String name, String wallet) {
    return 'Stops showing $name in this app; $wallet keeps its recovery phrase';
  }

  @override
  String desktopAccountInfoDisconnectWalletSubtitle(String name, String wallet) {
    return '$name is the last account in $wallet, so the wallet goes with it';
  }

  @override
  String get desktopAccountInfoDisconnectHardware => 'Disconnect Hardware Account';

  @override
  String desktopAccountInfoDisconnectHardwareSubtitle(String name) {
    return 'Stops showing $name in this app; your device keeps its keys';
  }

  @override
  String get desktopAccountInfoDisconnectMultisig => 'Disconnect Multisig';

  @override
  String desktopAccountInfoDisconnectMultisigSubtitle(String name) {
    return 'Stops showing $name in this app; it stays on the chain';
  }

  @override
  String get desktopDisconnectTitle => 'Disconnect';

  @override
  String desktopDisconnectHeadline(String name) {
    return 'Stop showing $name?';
  }

  @override
  String get desktopDisconnectAccountEyebrow => 'Disconnect account';

  @override
  String desktopDisconnectAccountLine1(String name) {
    return '$name leaves this app; its funds stay on the blockchain';
  }

  @override
  String desktopDisconnectAccountLine2(String name, String wallet) {
    return '$wallet keeps its recovery phrase, so you can add $name back later';
  }

  @override
  String get desktopDisconnectHardwareEyebrow => 'Disconnect hardware account';

  @override
  String get desktopDisconnectHardwareLine2 => 'Your hardware wallet keeps its keys, so you can connect it again later';

  @override
  String get desktopDisconnectMultisigEyebrow => 'Disconnect multisig';

  @override
  String desktopDisconnectMultisigLine1(String name) {
    return '$name leaves this app; it stays on the chain with its signers';
  }

  @override
  String get desktopDisconnectMultisigLine2 => 'You can add it back later';

  @override
  String desktopDisconnectWalletHeadline(String wallet) {
    return 'This removes $wallet';
  }

  @override
  String desktopDisconnectWalletLine1(String name, String wallet) {
    return '$name is the last account in $wallet, so the whole wallet goes with it';
  }

  @override
  String desktopDisconnectWalletLine2(String wallet) {
    return '$wallet’s recovery phrase will be deleted from this device';
  }

  @override
  String get desktopDisconnectWalletLine3 => 'Its funds stay on the blockchain, but only that phrase can restore them';

  @override
  String desktopDisconnectWalletBackedUp(String wallet) {
    return 'I’ve backed up $wallet’s recovery phrase';
  }

  @override
  String desktopDisconnectWalletReason(String wallet) {
    return 'Delete $wallet and its recovery phrase';
  }

  @override
  String desktopDisconnectWalletDeclined(String wallet) {
    return 'Deleting $wallet needs your approval';
  }

  @override
  String desktopRecoveryPhraseWalletsSubtitle(int count) {
    return 'View the 24 words of each of your $count wallets';
  }

  @override
  String get desktopRecoveryPhraseChooseWallet => 'Choose a wallet';

  @override
  String get desktopWalletRenameFailed => 'Couldn\'t rename the wallet';

  @override
  String get desktopNotificationOpenAction => 'Open';

  @override
  String desktopNotificationSentTitle(String amount) {
    return 'Sent $amount';
  }

  @override
  String desktopNotificationSentBody(String account) {
    return 'From $account';
  }

  @override
  String desktopNotificationReceivedTitle(String amount) {
    return 'Received $amount';
  }

  @override
  String desktopNotificationReceivedBody(String account) {
    return 'In $account';
  }

  @override
  String desktopNotificationSwapBody(String amount, String foreignAmount, String network) {
    return '$amount for $foreignAmount on $network';
  }

  @override
  String desktopNotificationIncomingTitle(String amount) {
    return 'Incoming $amount';
  }

  @override
  String desktopNotificationIncomingBody(String account) {
    return 'Scheduled to arrive in $account';
  }

  @override
  String get desktopNotificationSendNotConfirmedTitle => 'Send not confirmed';

  @override
  String desktopNotificationSendNotConfirmedBody(String amount, String account) {
    return '$amount from $account wasn’t seen on the chain in time. It may have failed, or only be late.';
  }

  @override
  String get desktopNotificationSendFailedTitle => 'Send failed';

  @override
  String desktopNotificationSendFailedBody(String amount, String account) {
    return '$amount from $account was not sent.';
  }

  @override
  String get desktopNotificationProposalCreatedTitle => 'Proposal created';

  @override
  String desktopNotificationProposalCreatedBody(String amount, String multisig) {
    return 'Send $amount from $multisig';
  }

  @override
  String get desktopNotificationProposalNewTitle => 'New proposal';

  @override
  String desktopNotificationProposalSignedTitle(int count, int threshold) {
    return 'Proposal signed: $count of $threshold';
  }

  @override
  String get desktopNotificationProposalReadyTitle => 'Proposal ready to execute';

  @override
  String get desktopNotificationProposalExecutedTitle => 'Proposal executed';

  @override
  String get desktopNotificationProposalFailedTitle => 'Proposal execution failed';

  @override
  String get desktopNotificationProposalCancelledTitle => 'Proposal cancelled';

  @override
  String get desktopNotificationProposalRemovedTitle => 'Proposal removed';

  @override
  String desktopNotificationProposalOtherBody(String multisig) {
    return 'In $multisig';
  }

  @override
  String get desktopNotificationProposalNotConfirmedTitle => 'Proposal not confirmed';

  @override
  String desktopNotificationProposalNotConfirmedBody(String amount, String multisig) {
    return 'The proposal to send $amount from $multisig wasn’t seen on the chain in time.';
  }

  @override
  String desktopWalletAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count accounts', one: '1 account');
    return '$_temp0';
  }

  @override
  String get importWalletAlreadyAdded => 'This wallet is already in the app';

  @override
  String get desktopMenuImportWallet => 'Import Wallet…';

  @override
  String get desktopImportFinding => 'Finding this wallet\'s accounts';

  @override
  String get desktopImportFailed => 'Couldn\'t import the wallet';

  @override
  String get desktopImportDone => 'Wallet imported';

  @override
  String get desktopMenuManageMultisigs => 'Manage Multisigs…';

  @override
  String get desktopManageMultisigsTitle => 'Manage Multisigs';

  @override
  String get desktopManageMultisigsLead =>
      'Multisigs on chain where one of your accounts is a signer. Switching one off removes it from this app only.';

  @override
  String get desktopManageMultisigsFinding => 'Finding your multisigs on chain';

  @override
  String desktopManageMultisigsSignsAs(String approvals, String name) {
    return '$approvals · you sign as $name';
  }

  @override
  String get desktopMenuCreateMultisig => 'Create Multisig…';

  @override
  String get desktopCreateMultisigSigners => 'Signers';

  @override
  String get desktopCreateMultisigApprovalsNeeded => 'Approvals needed';

  @override
  String get desktopCreateMultisigApprovals => 'Approvals';

  @override
  String desktopCreateMultisigApprovalsValue(int count, int total) {
    return '$count of $total signers';
  }

  @override
  String get desktopCreateMultisigAddress => 'Address';

  @override
  String get desktopCreateMultisigPaidBy => 'Paid by';

  @override
  String get desktopCreateMultisigCreationFee => 'Creation fee';

  @override
  String get desktopCreateMultisigRemoveSigner => 'Remove signer';

  @override
  String desktopCreateMultisigPreviewFailed(String error) {
    return 'Could not work out the new address: $error';
  }

  @override
  String desktopCreateMultisigCantAfford(String name) {
    return '$name can’t cover what this costs';
  }

  @override
  String get desktopCreateMultisigDeclined => 'Creating this multisig needs your approval';

  @override
  String desktopCreateMultisigFailed(String error) {
    return 'Could not create this multisig: $error';
  }

  @override
  String get desktopCreateMultisigTimedOut => 'Multisig not confirmed';

  @override
  String get desktopMenuConnectColdWallet => 'Connect Cold Wallet…';

  @override
  String get desktopColdWalletAddAccountTitle => 'Add Cold Wallet Account';

  @override
  String get desktopColdWalletStepHold => 'Hold it up to this camera';

  @override
  String get desktopColdWalletLooking => 'Looking for a QR code';

  @override
  String get desktopColdWalletNotAddress => 'That QR code isn\'t an account address.';

  @override
  String get desktopColdWalletAlreadyAdded => 'That account is already in this app.';

  @override
  String get desktopColdWalletConfirmTitle => 'Confirm Address';

  @override
  String get desktopColdWalletConfirmBody => 'Check that this matches the address on your cold wallet.';

  @override
  String get desktopColdWalletScanAgain => 'Scan Again';

  @override
  String get desktopColdWalletConnect => 'Connect';

  @override
  String get desktopColdWalletSaveFailed => 'Couldn\'t connect this cold wallet';

  @override
  String get desktopCameraNoneTitle => 'No camera found';

  @override
  String get desktopCameraNoneBody => 'Connect a camera to this computer, then try again.';

  @override
  String get desktopCameraPermissionTitle => 'Camera access is off';

  @override
  String get desktopCameraPermissionMac => 'Allow Quantus Wallet under Privacy & Security, Camera.';

  @override
  String get desktopCameraPermissionWindows => 'Allow camera access under Privacy & security, Camera.';

  @override
  String get desktopCameraPermissionLinux => 'Check that your user is allowed to use the camera.';

  @override
  String get desktopCameraOpenSettings => 'Open System Settings';

  @override
  String get desktopCameraBusyTitle => 'The camera is in use';

  @override
  String get desktopCameraBusyBody => 'Close the other app using it, then try again.';

  @override
  String get desktopCameraUnsupportedTitle => 'This camera can\'t be used';

  @override
  String get desktopCameraUnsupportedBody => 'It offers no picture format this app can read.';

  @override
  String get desktopCameraMediaTitle => 'Camera support is missing';

  @override
  String get desktopCameraMediaBody => 'Install the Media Feature Pack for Windows, then try again.';

  @override
  String get desktopCameraStoppedTitle => 'The camera stopped';

  @override
  String get desktopCameraStoppedBody => 'Check that it\'s connected, then try again.';

  @override
  String get desktopCameraFailedTitle => 'Couldn\'t use the camera';

  @override
  String get desktopCameraFailedBody => 'Something went wrong with the camera. Try again.';

  @override
  String get settingsHelpDiscord => 'Discord';

  @override
  String get swapSaveAddressFailed => 'Could not save the address.';

  @override
  String get commonSupportScamWarning => 'Support will never DM you first or ask for your recovery phrase.';

  @override
  String desktopNotificationEncryptedSendFailedBody(String amount, String account) {
    return '$amount from $account didn’t finish sending. Part of it may have gone through.';
  }

  @override
  String get desktopSwapAwaitingDeposit => 'Awaiting deposit';

  @override
  String get desktopSwapWaitingForDeposit => 'Waiting for your deposit';

  @override
  String desktopSwapUntil(String time) {
    return 'until $time';
  }

  @override
  String get desktopSwapFor => 'For';

  @override
  String desktopSwapAmountOnNetwork(String amount, String network) {
    return '$amount on $network';
  }

  @override
  String desktopSwapForAmountOnNetwork(String amount, String network) {
    return 'for $amount on $network';
  }

  @override
  String desktopSwapRecipientOn(String network) {
    return 'Recipient on $network';
  }

  @override
  String get desktopSwapTheRecipient => 'the recipient';

  @override
  String desktopSwapSendAmount(String amount) {
    return 'Send $amount';
  }

  @override
  String get desktopSwapCancel => 'Cancel Swap';

  @override
  String get desktopSwapViewDeposit => 'View Deposit';

  @override
  String desktopSwapReceived(String amount) {
    return '$amount received';
  }

  @override
  String desktopSwapCompleteBody(String amount) {
    return 'Your swap of $amount is complete.';
  }

  @override
  String get desktopSwapPoweredByNearIntents => 'Powered by NEAR Intents';

  @override
  String desktopSwapRecipientAddressOn(String network) {
    return 'Recipient address on $network';
  }

  @override
  String desktopSwapRefundAddressOn(String network) {
    return 'Refund address on $network';
  }

  @override
  String get desktopSwapMaximum => 'Swap the maximum amount';

  @override
  String desktopSwapAccountAvailable(String account, String amount) {
    return '$account · $amount available';
  }

  @override
  String get desktopSwapLoadingTokens => 'Loading tokens';

  @override
  String get desktopSwapRemoveSavedAddress => 'Remove Saved Address';

  @override
  String desktopSwapSavedAddressesUnavailable(String error) {
    return 'Saved addresses are unavailable: $error';
  }

  @override
  String get desktopNotificationNotAllowed => 'Not allowed in System Settings';

  @override
  String get desktopNotificationOpenSystemSettings => 'Open System Settings';

  @override
  String get desktopNotificationOpenSystemSettingsFailed => 'Couldn’t open System Settings';

  @override
  String desktopNotificationUnavailable(String reason) {
    return 'Unavailable: $reason';
  }

  @override
  String desktopStatusItemOpen(String appName) {
    return 'Open $appName';
  }

  @override
  String desktopStatusItemQuit(String appName) {
    return 'Quit $appName';
  }

  @override
  String get desktopQuitPendingTitle => 'A Transaction Is Still Under Way';

  @override
  String get desktopQuitPendingBody =>
      'Quitting now could leave it unfinished. The wallet can finish first, then quit on its own.';

  @override
  String get desktopQuitFinishFirst => 'Finish, Then Quit';

  @override
  String get desktopQuitNow => 'Quit Now';

  @override
  String get desktopKeystoneStepShow => 'Show';

  @override
  String get desktopKeystoneStepCheckAndScan => 'Check and scan back';

  @override
  String get desktopKeystoneOnColdWallet => 'On your cold wallet';

  @override
  String get desktopKeystoneShowStepScan => 'Open your cold wallet and choose Scan.';

  @override
  String get desktopKeystoneShowStepHold => 'Hold it up to this QR code until it shows the transaction.';

  @override
  String get desktopKeystoneShowStepContinue => 'Then continue here.';

  @override
  String get desktopKeystoneCheckTitle => 'Check your cold wallet\'s screen';

  @override
  String get desktopKeystoneCheckBody => 'Approve there only if it shows exactly this.';

  @override
  String get desktopKeystoneThen => 'Then';

  @override
  String get desktopKeystoneScanStepHold => 'Hold its signature QR code up to this computer\'s camera.';

  @override
  String get desktopKeystoneScanStepKeep => 'Keep it there until every part has arrived.';

  @override
  String get desktopKeystoneRejectStep2Title => 'Don\'t retry from this computer.';

  @override
  String get desktopKeystoneRejectStep3Body =>
      'Keys never left the device. Move to a trusted computer before sending again.';

  @override
  String get desktopKeystoneRejectStep2Body => 'If it\'s compromised, retrying gives the attacker another chance.';
}
