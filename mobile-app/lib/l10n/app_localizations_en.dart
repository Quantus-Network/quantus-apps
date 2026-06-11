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
  String get addAccountMenuMultisigTitle => 'Create Multisig';

  @override
  String get addAccountMenuMultisigSubtitle => 'Set up a shared address with multiple signers';

  @override
  String get addAccountMenuDiscoverMultisigTitle => 'Discover Multisig';

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
  String get multisigCreateAuthReason => 'Authenticate to create this multisig';

  @override
  String get multisigCreateSignersLabel => 'SIGNERS';

  @override
  String get multisigCreateSignersSubtitle => 'Add at least one other signer besides yourself.';

  @override
  String get multisigCreateAddSignerHint => 'Signer SS58 address';

  @override
  String get multisigCreateAddSignerButton => 'Add Signer';

  @override
  String get multisigCreateDuplicateSigner => 'This signer is already in the list.';

  @override
  String get multisigCreateInvalidSigner => 'Enter a valid SS58 address.';

  @override
  String get multisigCreateThresholdLabel => 'THRESHOLD';

  @override
  String multisigCreateThresholdValue(int count, int total) {
    return '$count of $total';
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
  String get multisigStatusApproved => 'APPROVED';

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
  String get activityTxApproving => 'Approving…';

  @override
  String get activityTxCancelling => 'Cancelling…';

  @override
  String get multisigApprovalTimeoutToast =>
      'Approval confirmation is taking longer than expected. Check the chain or try again.';

  @override
  String get multisigProposalAlreadySignedNote => 'You\'ve already approved this proposal.';

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
  String get multisigApproveButton => 'Approve';

  @override
  String get multisigAlreadyApproved => 'Already Approved';

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
  String get activityDetailDate => 'DATE';

  @override
  String get activityDetailNetworkFee => 'NETWORK FEE';

  @override
  String get activityDetailTxHash => 'TX HASH';

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
