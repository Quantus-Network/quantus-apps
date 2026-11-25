import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/utils/account_utils.dart';
import 'package:wallet_core/utils/explorer_url.dart';
import 'package:wallet_core/utils/recipient_rememberer.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// Standard single-signer transfer from the active account. Signs locally, or
/// hands off to the Keystone QR flow for hardware accounts.
///
/// The source [account] is captured when the flow starts and used for the whole
/// flow (fee estimation, balance validation, submission), so a mid-flow account
/// switch can never change the account being signed from.
class RegularSendStrategy extends SendStrategy {
  final Account account;

  const RegularSendStrategy({required this.account});

  @override
  String? get sourceAccountId => account.accountId;

  @override
  SendStrings strings(AppLocalizations l10n) => SendStrings(
    flowTitle: l10n.sendTitle,
    recipientSectionLabel: l10n.sendSelectRecipientSendTo,
    amountRecipientCardLabel: l10n.sendInputAmountSendTo,
    feeLabel: l10n.sendInputAmountNetworkFee,
    feeFetchFailedMessage: l10n.multisigProposeFeeFetchFailed,
    reviewButtonLabel: l10n.sendLogicReviewSend,
    reviewHeroLabel: l10n.sendReviewSending,
    reviewConfirmLabel: l10n.sendReviewConfirm,
  );

  /// The whole effective balance, bound to the account captured at flow start
  /// so a mid-flow account switch cannot change what is validated against.
  @override
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider =>
      effectiveBalanceProviderFamily(account.accountId);

  @override
  bool extraBalancesLoading(WidgetRef ref) => false;

  @override
  BigInt feeChargedToBalance(SendFee? fee) => (fee as RegularFee?)?.networkFee ?? BigInt.zero;

  @override
  bool get supportsSendAll => true;

  /// The chain fee moves with the amount only through its compact encoding, a
  /// few bytes at most, so the latest value serves every amount until the next
  /// query lands.
  @override
  ProviderListenable<SendFeeState> feeProvider({required String recipient, required BigInt amount}) => sendFeeProvider;

  @override
  void requestFee(
    ProviderReader read, {
    required String recipient,
    required BigInt amount,
    bool sendAll = false,
    bool immediate = false,
  }) => read(
    sendFeeProvider.notifier,
  ).request(_feeFetcher(read, recipient, amount, sendAll: sendAll), immediate: immediate);

  @override
  void retryFee(WidgetRef ref, {required String recipient, required BigInt amount}) =>
      ref.read(sendFeeProvider.notifier).retry();

  @override
  bool feeApplies(SendFee fee, {required BigInt amount, required bool sendAll}) {
    final regularFee = fee as RegularFee;
    return regularFee.sendAll == sendAll && (sendAll || regularFee.amount == amount);
  }

  /// Dummy-signed `payment_queryInfo` probe from the captured account, with
  /// its inputs resolved now so it can run after the requesting screen is gone.
  Future<RegularFee> Function() _feeFetcher(
    ProviderReader read,
    String recipient,
    BigInt amount, {
    required bool sendAll,
  }) {
    final substrate = read(substrateServiceProvider);
    final call = _transferCall(read, recipient, amount, sendAll: sendAll);
    return () async => RegularFee(
      networkFee: (await substrate.getFeeForCall(account, call)).fee,
      amount: sendAll ? null : amount,
      sendAll: sendAll,
    );
  }

  /// Chain fee for a transfer of [amount] to [recipient].
  Future<RegularFee> fetchFee(ProviderReader read, {required String recipient, required BigInt amount}) =>
      _feeFetcher(read, recipient, amount, sendAll: false)();

  @override
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n) => null;

  /// Max sends use `transfer_all` with keep-alive off: the chain sizes the
  /// amount at inclusion and reaps the account, so the fee can never make
  /// them fail and nothing is left behind. The fee itself is fixed because
  /// the call carries no amount.
  RuntimeCall _transferCall(ProviderReader read, String recipient, BigInt amount, {required bool sendAll}) {
    final balances = read(balancesServiceProvider);
    return sendAll ? balances.getTransferAllCall(recipient) : balances.getBalanceTransferCall(recipient, amount);
  }

  KeystoneSignCacheKey _hardwareCacheKey(String recipient, BigInt amount, {required bool sendAll}) => sendAll
      ? KeystoneSignCacheKey.forExtrinsic(accountId: account.accountId, identity: 'transfer_all|$recipient')
      : KeystoneSignCacheKey.fromSendParams(accountId: account.accountId, recipientAddress: recipient, amount: amount);

  @override
  Future<void> prefetchSignPayload(
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
    bool sendAll = false,
  }) async {
    if (!account.signsWithHardware) return;
    final recipient = recipientAddress.trim();
    await ensureKeystoneSignPayload(
      ref,
      account: account,
      buildCall: () => _transferCall(ref.read, recipient, amount, sendAll: sendAll),
      cacheKey: _hardwareCacheKey(recipient, amount, sendAll: sendAll),
    );
  }

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
    final networkFee = (fee as RegularFee).networkFee;
    final addr = recipientAddress.trim();

    String amt(BigInt v, {bool estimate = false}) => estimateLabel(
      l10n.commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol),
      estimate: estimate,
    );

    // A max send pays the whole spendable balance, so only its split into
    // amount and fee moves until the fee settles; otherwise the amount is fixed
    // and the total moves with the fee.
    return [
      SendReviewText(l10n.sendReviewTo, addr, kind: SendReviewRowKind.recipient),
      SendReviewText(
        l10n.sendReviewAmount,
        amt(amount, estimate: feeIsEstimate && sendAll),
        kind: SendReviewRowKind.amount,
      ),
      SendReviewText(l10n.sendReviewNetworkFee, amt(networkFee, estimate: feeIsEstimate), kind: SendReviewRowKind.fee),
      SendReviewText(
        l10n.sendReviewYouPay,
        amt(amount + networkFee, estimate: feeIsEstimate && !sendAll),
        kind: SendReviewRowKind.total,
      ),
    ];
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
    final regularFee = fee as RegularFee;
    if (sendAll && !regularFee.sendAll) {
      throw StateError('Max send reached submit with a fee that did not price transfer_all');
    }
    final recipient = recipientAddress.trim();
    // Sign from the account captured when the flow started, not whichever
    // account happens to be active at submit time.
    final account = this.account;
    final terminal = buildSentTerminalContent(l10n, fmt, recipient: recipient, amount: amount, isPayMode: isPayMode);

    // Keystone (hardware) accounts sign off-device: hand off to the QR flow
    // instead of signing locally. The debug flag forces this path for testing.
    if (account.signsWithHardware) {
      // Taken now: the signature can come back long after, past a wallet reset.
      final walletSession = ref.read(walletSessionProvider);
      final ticket = walletSession.ticket;
      return SendNeedsHardwareSignature(
        session: KeystoneSigningSession(
          account: account,
          buildCall: () => _transferCall(ref.read, recipient, amount, sendAll: sendAll),
          // A max send's `transfer_all` carries no amount: the cold wallet shows
          // these words in its place.
          primaryDetail: sendAll
              ? l10n.keystoneSignEntireBalance
              : l10n.commonAmountBalance(fmt.formatBalance(amount, smartDecimals: 4), AppConstants.tokenSymbol),
          secondaryDetail: recipient,
          secondaryIsAddress: true,
          cacheKey: _hardwareCacheKey(recipient, amount, sendAll: sendAll),
          telemetryPrefix: 'send_transfer_hardware',
          submitSigned: (ref, {required unsignedData, required signatureWithPublicKey}) async {
            if (!walletSession.isCurrent(ticket)) {
              throw StateError('The wallet was reset before this send was signed');
            }
            final rememberRecipient = recipientRememberer(ref.read);
            final hash = await ref
                .read(transactionSubmissionServiceProvider)
                .submitExternallySignedTransfer(
                  account: account,
                  targetAddress: recipient,
                  amount: amount,
                  fee: regularFee.networkFee,
                  blockHeight: unsignedData.payloadToSign.blockNumber,
                  unsignedData: unsignedData,
                  signatureWithPublicKey: signatureWithPublicKey,
                );
            rememberRecipient(recipient);
            return hash;
          },
        ),
        terminalForHash: (hash) => terminal.copyWith(explorerUrl: explorerUrl('transactions/$hash')),
      );
    }

    final rememberRecipient = recipientRememberer(ref.read);
    try {
      final hash = await submitLocal(
        ref,
        recipient: recipient,
        amount: amount,
        networkFee: regularFee.networkFee,
        sendAll: sendAll,
      );
      if (hash == null) return SendFailed(l10n.sendReviewAuthRequired);
      rememberRecipient(recipient);
      return SendSubmitted(terminal.copyWith(explorerUrl: explorerUrl('transactions/$hash')));
    } catch (e) {
      quantusPrint('Transfer failed: $e');
      return SendFailed(l10n.sendReviewSubmitFailed);
    }
  }

  /// Asks for the device's approval and submits a transfer signed with the
  /// local key. Returns the extrinsic hash, or null when approval was not
  /// given or [proceed], asked once it was, no longer wants the transfer:
  /// the prompt can be up for a while and terms can change under it.
  Future<String?> submitLocal(
    WidgetRef ref, {
    required String recipient,
    required BigInt amount,
    required BigInt networkFee,
    bool sendAll = false,
    FutureOr<bool> Function()? proceed,
  }) async {
    if (account.signsWithHardware) throw StateError('Account ${account.accountId} signs with hardware');
    final session = ref.read(walletSessionProvider);
    final ticket = session.ticket;
    final approval = await ref.read(userApprovalProvider).approve(reason: ref.read(l10nProvider).sendReviewAuthReason);
    if (approval != ApprovalResult.approved) return null;
    final stillWantedAfterApproval = proceed == null || await proceed();
    if (!stillWantedAfterApproval) return null;
    if (!session.isCurrent(ticket)) throw StateError('The wallet was reset while this transfer awaited approval');
    return ref
        .read(transactionSubmissionServiceProvider)
        .balanceTransfer(
          account,
          call: _transferCall(ref.read, recipient, amount, sendAll: sendAll),
          targetAddress: recipient,
          amount: amount,
          fee: networkFee,
        );
  }
}
