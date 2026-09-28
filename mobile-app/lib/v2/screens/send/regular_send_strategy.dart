import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/url_utils.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_fee_notifier.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/shared/utils/provider_reader.dart';

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

  @override
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider =>
      effectiveMaxBalanceProviderFamily(account.accountId);

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

  /// Max sends use `transfer_all`: the chain sizes the amount at inclusion, so
  /// the fee can never make them fail, and the fee itself is fixed because the
  /// call carries no amount.
  RuntimeCall _transferCall(ProviderReader read, String recipient, BigInt amount, {required bool sendAll}) {
    final balances = read(balancesServiceProvider);
    return sendAll
        ? balances.getTransferAllCall(recipient, keepAlive: read(existentialDepositToggleProvider))
        : balances.getBalanceTransferCall(recipient, amount);
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
  List<Widget> reviewRows(
    BuildContext context,
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
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewTo, value: addr),
      const SizedBox(height: 7),
      DetailSummaryRow.review(
        label: l10n.sendReviewAmount,
        value: amt(amount, estimate: feeIsEstimate && sendAll),
      ),
      const SizedBox(height: 7),
      DetailSummaryRow.review(
        label: l10n.sendReviewNetworkFee,
        value: amt(networkFee, estimate: feeIsEstimate),
      ),
      const SizedBox(height: 7),
      DetailSummaryRow.review(
        label: l10n.sendReviewYouPay,
        value: amt(amount + networkFee, estimate: feeIsEstimate && !sendAll),
      ),
      const SizedBox(height: 7),
    ];
  }

  @override
  Future<SendOutcome> submit(
    WidgetRef ref, {
    required String recipientAddress,
    required String recipientChecksum,
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
    final terminal = buildSentTerminalContent(
      l10n,
      fmt,
      recipient: recipient,
      checksum: recipientChecksum,
      amount: amount,
      isPayMode: isPayMode,
    );

    // Keystone (hardware) accounts sign off-device: hand off to the QR flow
    // instead of signing locally. The debug flag forces this path for testing.
    if (account.signsWithHardware) {
      return SendNeedsHardwareSignature(
        session: KeystoneSigningSession(
          account: account,
          buildCall: () => _transferCall(ref.read, recipient, amount, sendAll: sendAll),
          primaryDetail: l10n.commonAmountBalance(
            fmt.formatBalance(amount, smartDecimals: 4),
            AppConstants.tokenSymbol,
          ),
          secondaryDetail: recipient,
          tertiaryDetail: recipientChecksum,
          cacheKey: _hardwareCacheKey(recipient, amount, sendAll: sendAll),
          telemetryPrefix: 'send_transfer_hardware',
          submitSigned: (ref, {required unsignedData, required signatureWithPublicKey}) async {
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
            unawaited(
              RecentAddressesService()
                  .addAddress(recipient)
                  .catchError((Object error) => quantusPrint('Failed to save recent address: $error')),
            );
            return hash;
          },
        ),
        terminalForHash: (hash) => terminal.copyWith(explorerUrl: explorerImmediateTransactionUrl(hash)),
      );
    }

    try {
      final hash = await submitLocal(
        ref,
        recipient: recipient,
        amount: amount,
        networkFee: regularFee.networkFee,
        sendAll: sendAll,
      );
      if (hash == null) return SendFailed(l10n.sendReviewAuthRequired);
      unawaited(
        RecentAddressesService()
            .addAddress(recipient)
            .catchError((Object e) => quantusPrint('Failed to save recent address: $e')),
      );
      return SendSubmitted(terminal.copyWith(explorerUrl: explorerImmediateTransactionUrl(hash)));
    } catch (e) {
      quantusPrint('Transfer failed: $e');
      return SendFailed(l10n.sendReviewSubmitFailed);
    }
  }

  /// Authenticates the user and submits a transfer signed with the local key.
  /// Returns the extrinsic hash, or null when authentication was declined.
  Future<String?> submitLocal(
    WidgetRef ref, {
    required String recipient,
    required BigInt amount,
    required BigInt networkFee,
    bool sendAll = false,
  }) async {
    if (account.signsWithHardware) throw StateError('Account ${account.accountId} signs with hardware');
    final authed = await LocalAuthService().authenticate(localizedReason: ref.read(l10nProvider).sendReviewAuthReason);
    if (!authed) return null;
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
