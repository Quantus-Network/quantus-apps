import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/utils/account_utils.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/utils/explorer_url.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';
import 'package:wallet_core/utils/recipient_rememberer.dart';

/// Proposal cost for a recipient. The network fee is still a chain estimate,
/// so it is keyed by recipient only and sized with a representative amount —
/// the amount moves the encoded length by a few bytes at most — rather than
/// re-fetched on every keystroke.
final multisigProposeFeeProvider = FutureProvider.autoDispose.family<SendFee, (MultisigAccount msig, String recipient)>(
  (ref, key) async {
    final (msig, recipient) = key;
    final service = ref.read(multisigServiceProvider);
    final signer = ref.read(accountsProvider).value?.where((a) => a.accountId == msig.myMemberAccountId).firstOrNull;
    try {
      if (signer != null) {
        return ProposeFee(
          await service.estimateProposeFeeBreakdown(
            msig: msig,
            signer: signer,
            recipient: recipient,
            amount: MultisigProposeStrategy._estimateFeeAmount,
          ),
        );
      }
      final currentBlock = await service.currentBlockNumber();
      return ProposeFee(
        ProposeFeeBreakdown(
          networkFee: BigInt.zero,
          deposit: service.proposalDeposit,
          creationFee: service.proposalCreationFee(msig.signers.length),
          expiryBlock: currentBlock + service.blocksForDuration(MultisigService.defaultProposalExpiry),
        ),
      );
    } catch (e, st) {
      quantusPrint('Propose fee estimate failed: $e\n$st');
      rethrow;
    }
  },
);

/// Proposes a transfer from a multisig account. The multisig is a view-only
/// account, so funds leave from [msig] while the proposing member pays the fee.
class MultisigProposeStrategy extends SendStrategy {
  final MultisigAccount msig;

  const MultisigProposeStrategy({required this.msig});

  static final BigInt _estimateFeeAmount = BigInt.from(1000) * NumberFormattingService.scaleFactorBigInt;

  @override
  String? get sourceAccountId => msig.accountId;

  @override
  SendStrings strings(AppLocalizations l10n) => SendStrings(
    flowTitle: l10n.multisigProposeTitle,
    recipientSectionLabel: l10n.multisigProposeSelectRecipientTo,
    amountRecipientCardLabel: l10n.multisigProposeAmountToLabel,
    feeLabel: l10n.multisigProposeFeeLabel,
    feeFetchFailedMessage: l10n.multisigProposeFeeFetchFailed,
    reviewButtonLabel: l10n.multisigProposeReviewButton,
    reviewHeroLabel: l10n.multisigProposeReviewProposing,
    reviewConfirmLabel: l10n.multisigProposeCreateButton,
  );

  @override
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider => balanceProviderFamily(msig.accountId);

  @override
  bool extraBalancesLoading(WidgetRef ref) =>
      !ref.watch(effectiveBalanceProviderFamily(msig.myMemberAccountId)).hasValue;

  // The proposal fee is paid by the member, not from the multisig balance.
  @override
  BigInt feeChargedToBalance(SendFee? fee) => BigInt.zero;

  @override
  ProviderListenable<AsyncValue<BigInt>>? get feePayerBalanceProvider =>
      effectiveBalanceProviderFamily(msig.myMemberAccountId);

  @override
  String? feePayerBalanceLabel(AppLocalizations l10n) => l10n.multisigProposeFeePayerBalanceLabel;

  @override
  ProviderListenable<SendFeeState> feeProvider({required String recipient, required BigInt amount}) =>
      multisigProposeFeeProvider((msig, recipient.trim())).select(SendFeeState.fromAsync);

  @override
  void retryFee(WidgetRef ref, {required String recipient, required BigInt amount}) =>
      ref.invalidate(multisigProposeFeeProvider((msig, recipient.trim())));

  @override
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n) =>
      _coversCost(ref.watch(effectiveBalanceProviderFamily(msig.myMemberAccountId)).value, fee)
      ? null
      : l10n.multisigProposeFeePayerInsufficient;

  /// The member's account holding [memberBalance] can pay [fee]. A balance
  /// that is not known is no objection: the flows open no review without it.
  static bool _coversCost(BigInt? memberBalance, SendFee fee) =>
      memberBalance == null || memberBalance >= fee.displayFee;

  /// As [_coversCost], of what the member's account holds now, from where
  /// nothing is watched.
  bool _memberCoversCost(WidgetRef ref, SendFee fee) =>
      _coversCost(ref.read(effectiveBalanceProviderFamily(msig.myMemberAccountId)).value, fee);

  @override
  List<SendReviewRow> reviewRows(
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
    bool feeIsEstimate = false,
    bool sendAll = false,
  }) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final multisigService = ref.watch(multisigServiceProvider);
    final currentBlock = ref.watch(multisigCurrentBlockProvider).value;
    final breakdown = (fee as ProposeFee).breakdown;

    String amt(BigInt v) =>
        l10n.commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);

    return [
      SendReviewAddress(l10n.multisigProposeProposerLabel, msig.myMemberAccountId, kind: SendReviewRowKind.signer),
      SendReviewText(l10n.sendReviewAmount, amt(amount), kind: SendReviewRowKind.amount),
      SendReviewThreshold(l10n.multisigProposeThresholdLabel, threshold: msig.threshold, signers: msig.signers.length),
      SendReviewExpiry(
        l10n.multisigProposeExpiresLabel,
        resolveMultisigExpiryParts(
          l10n: l10n,
          expiryBlock: breakdown.expiryBlock,
          multisigService: multisigService,
          currentBlock: currentBlock,
        ),
      ),
      SendReviewText(l10n.sendReviewNetworkFee, amt(breakdown.networkFee), kind: SendReviewRowKind.fee),
      SendReviewText(l10n.multisigProposalDepositLabel, amt(breakdown.deposit), kind: SendReviewRowKind.deposit),
      SendReviewText(l10n.multisigProposeFeeRowLabel, amt(breakdown.creationFee), kind: SendReviewRowKind.charge),
      SendReviewText(l10n.multisigProposeMemberTotalLabel, amt(breakdown.memberCost), kind: SendReviewRowKind.total),
    ];
  }

  Account _signer(WidgetRef ref) {
    final signer = ref
        .read(accountsProvider)
        .value
        ?.firstWhere(
          (a) => a.accountId == msig.myMemberAccountId,
          orElse: () => throw Exception('Member account not found in local wallet'),
        );
    if (signer == null) throw Exception('No signer account available');
    return signer;
  }

  RuntimeCall _proposeCall(
    WidgetRef ref, {
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
  }) => ref
      .read(multisigServiceProvider)
      .buildProposeTransferCall(msig: msig, recipient: recipient, amount: amount, expiryBlock: expiryBlock);

  KeystoneSignCacheKey _hardwareCacheKey(
    Account signer, {
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
  }) => KeystoneSignCacheKey.forExtrinsic(
    accountId: signer.accountId,
    identity: 'propose|${msig.accountId}|$recipient|$amount|$expiryBlock',
  );

  @override
  Future<void> prefetchSignPayload(
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
    bool sendAll = false,
  }) async {
    final signer = _signer(ref);
    if (!signer.signsWithHardware) return;
    final recipient = recipientAddress.trim();
    final expiryBlock = (fee as ProposeFee).breakdown.expiryBlock;
    await ensureKeystoneSignPayload(
      ref,
      account: signer,
      buildCall: () => _proposeCall(ref, recipient: recipient, amount: amount, expiryBlock: expiryBlock),
      cacheKey: _hardwareCacheKey(signer, recipient: recipient, amount: amount, expiryBlock: expiryBlock),
    );
  }

  @override
  Future<SendOutcome> submit(
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
    required bool isPayMode,
    bool sendAll = false,
  }) async {
    final l10n = ref.read(l10nProvider);
    final fmt = ref.read(numberFormattingServiceProvider);
    final breakdown = (fee as ProposeFee).breakdown;
    final recipient = recipientAddress.trim();
    final terminal = _terminal(l10n, fmt, recipient: recipient, amount: amount);
    final walletSession = ref.read(walletSessionProvider);
    final ticket = walletSession.ticket;

    final Account signer;
    try {
      signer = _signer(ref);
    } catch (e, st) {
      quantusPrint('Propose signer error: $e $st');
      return SendFailed(l10n.multisigProposeSubmitFailed);
    }

    // Keystone members sign off-device: hand off to the QR flow, which submits
    // the proposal once the signature is scanned back.
    if (signer.signsWithHardware) {
      return SendNeedsHardwareSignature(
        session: KeystoneSigningSession(
          account: signer,
          buildCall: () => _proposeCall(ref, recipient: recipient, amount: amount, expiryBlock: breakdown.expiryBlock),
          primaryDetail: l10n.commonAmountBalance(
            fmt.formatBalance(amount, smartDecimals: 4),
            AppConstants.tokenSymbol,
          ),
          primaryIsAmount: true,
          secondaryDetail: recipient,
          secondaryIsAddress: true,
          cacheKey: _hardwareCacheKey(signer, recipient: recipient, amount: amount, expiryBlock: breakdown.expiryBlock),
          telemetryPrefix: 'multisig_propose_hardware',
          submitSigned: (ref, {required unsignedData, required signatureWithPublicKey}) async {
            if (!walletSession.isCurrent(ticket)) {
              throw StateError('The wallet was reset before this proposal was signed');
            }
            final afterProposed = _afterProposedBy(ref, recipient);
            final hash = await ref
                .read(transactionSubmissionServiceProvider)
                .proposeTransferWithExternalSignature(
                  msig: msig,
                  signer: signer,
                  recipient: recipient,
                  amount: amount,
                  expiryBlock: breakdown.expiryBlock,
                  feeBreakdown: breakdown,
                  unsignedData: unsignedData,
                  signatureWithPublicKey: signatureWithPublicKey,
                );
            afterProposed();
            return hash;
          },
        ),
        terminalForHash: (_) => terminal,
      );
    }

    // What the member holds can have moved since the review was drawn, and
    // again while the approval was asked for. A proposal its member cannot
    // pay for is included all the same, and fails at the cost of its fee.
    if (!_memberCoversCost(ref, fee)) return SendFailed(l10n.multisigProposeFeePayerInsufficient);
    final afterProposed = _afterProposedBy(ref, recipient);
    final approval = await ref.read(userApprovalProvider).approve(reason: l10n.multisigProposeAuthReason);
    if (approval != ApprovalResult.approved) return SendFailed(l10n.multisigProposeAuthRequired);
    if (!walletSession.stillCurrent(ticket, dropping: 'a proposal approved before the reset')) {
      return SendFailed(l10n.multisigProposeSubmitFailed);
    }
    if (!_memberCoversCost(ref, fee)) return SendFailed(l10n.multisigProposeFeePayerInsufficient);

    try {
      final hash = await ref
          .read(transactionSubmissionServiceProvider)
          .proposeTransfer(
            msig: msig,
            signer: signer,
            recipient: recipient,
            amount: amount,
            expiryBlock: breakdown.expiryBlock,
            feeBreakdown: breakdown,
          );
      afterProposed();
      // Broadcast is not created: what the terminal says of the proposal
      // holds once the wallet has seen the transaction create it.
      return SendSubmitted(
        terminal.copyWith(explorerUrl: multisigProposalExplorerUrl(hash)),
        confirmation: multisigProposalConfirmationProvider(hash),
      );
    } catch (e, st) {
      quantusPrint('Propose submit error: $e $st');
      return SendFailed(l10n.multisigProposeSubmitFailed);
    }
  }

  /// What follows a proposal going out. Taken before it goes out: after a
  /// reset in between, none of it may reach the next wallet.
  void Function() _afterProposedBy(WidgetRef ref, String recipient) {
    final session = ref.read(walletSessionProvider);
    final ticket = session.ticket;
    final rememberRecipient = recipientRememberer(ref.read);
    return () {
      if (!session.stillCurrent(ticket, dropping: 'what follows a proposal that went out')) return;
      rememberRecipient(recipient);
      ref.invalidate(multisigOpenProposalsProvider(msig));
      ref.invalidate(multisigPastProposalsProvider(msig));
      ref.invalidate(multisigCurrentBlockProvider);
    };
  }

  SendTerminalContent _terminal(
    AppLocalizations l10n,
    NumberFormattingService fmt, {
    required String recipient,
    required BigInt amount,
  }) {
    return SendTerminalContent(
      title: l10n.multisigProposeTitle,
      headline: l10n.multisigProposeDoneHeadline,
      subline: l10n.multisigProposeDoneSubline,
      amountText: l10n.commonAmountBalance(fmt.formatBalance(amount, smartDecimals: 4), AppConstants.tokenSymbol),
      recipientAddress: recipient,
      signaturesLabel: l10n.multisigSignaturesCount(1, msig.threshold),
      doneLabel: l10n.multisigDone,
    );
  }
}
