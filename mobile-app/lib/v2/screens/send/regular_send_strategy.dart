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
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/url_utils.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

/// Ref-time a signed transfer is charged for, probed once per runtime version
/// (the metadata carries no call or extension weights).
final transferDispatchWeightProvider = FutureProvider.autoDispose<BigInt>((ref) async {
  try {
    return await ref.watch(balancesServiceProvider).transferDispatchWeight();
  } catch (e, st) {
    quantusPrint('Transfer weight probe failed: $e\n$st');
    rethrow;
  }
});

/// Transfer fee for an amount: base and length fee from the shipped metadata,
/// dispatch weight from [transferDispatchWeightProvider]. Address-independent.
final regularSendFeeProvider = Provider.autoDispose.family<AsyncValue<SendFee>, BigInt>((ref, amount) {
  final balances = ref.watch(balancesServiceProvider);
  return ref
      .watch(transferDispatchWeightProvider)
      .whenData<SendFee>((weight) => RegularFee(networkFee: balances.transferFee(amount, dispatchWeight: weight)));
});

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
  String? sourceAccountId(WidgetRef ref) => account.accountId;

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
  ProviderListenable<AsyncValue<SendFee>> feeProvider({required String recipient, required BigInt amount}) =>
      regularSendFeeProvider(amount);

  @override
  void retryFee(WidgetRef ref, {required String recipient, required BigInt amount}) =>
      ref.invalidate(transferDispatchWeightProvider);

  @override
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n) => null;

  bool get _signsWithHardware => account.accountType == AccountType.keystone || AppConstants.debugHardwareWallet;

  RuntimeCall _transferCall(WidgetRef ref, String recipient, BigInt amount) =>
      ref.read(balancesServiceProvider).getBalanceTransferCall(recipient, amount);

  KeystoneSignCacheKey _hardwareCacheKey(String recipient, BigInt amount) =>
      KeystoneSignCacheKey.fromSendParams(accountId: account.accountId, recipientAddress: recipient, amount: amount);

  @override
  Future<void> prefetchSignPayload(WidgetRef ref, {required String recipientAddress, required BigInt amount}) async {
    if (!_signsWithHardware) return;
    final recipient = recipientAddress.trim();
    await ensureKeystoneSignPayload(
      ref,
      account: account,
      buildCall: () => _transferCall(ref, recipient, amount),
      cacheKey: _hardwareCacheKey(recipient, amount),
    );
  }

  @override
  List<Widget> reviewRows(
    BuildContext context,
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
  }) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final networkFee = (fee as RegularFee).networkFee;
    final addr = recipientAddress.trim();

    String amt(BigInt v) =>
        l10n.commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);

    return [
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewTo, value: addr),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewAmount, value: amt(amount)),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewNetworkFee, value: amt(networkFee)),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewYouPay, value: amt(amount + networkFee)),
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
  }) async {
    final l10n = ref.read(l10nProvider);
    final fmt = ref.read(numberFormattingServiceProvider);
    final regularFee = fee as RegularFee;
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
    if (_signsWithHardware) {
      return SendNeedsHardwareSignature(
        session: KeystoneSigningSession(
          account: account,
          buildCall: () => _transferCall(ref, recipient, amount),
          primaryDetail: l10n.commonAmountBalance(
            fmt.formatBalance(amount, smartDecimals: 4),
            AppConstants.tokenSymbol,
          ),
          secondaryDetail: recipient,
          tertiaryDetail: recipientChecksum,
          cacheKey: _hardwareCacheKey(recipient, amount),
          telemetryPrefix: 'send_transfer_hardware',
          submitSigned: (ref, {required unsignedData, required signature, required publicKey}) async {
            final hash = await ref
                .read(transactionSubmissionServiceProvider)
                .submitExternallySignedTransfer(
                  account: account,
                  targetAddress: recipient,
                  amount: amount,
                  fee: regularFee.networkFee,
                  blockHeight: unsignedData.payloadToSign.blockNumber,
                  unsignedData: unsignedData,
                  signature: signature,
                  publicKey: publicKey,
                );
            unawaited(
              RecentAddressesService()
                  .addAddress(recipient)
                  .catchError((Object error) => quantusPrint('Failed to save recent address: $error')),
            );
            return hash;
          },
        ),
        terminal: terminal,
      );
    }

    final authed = await LocalAuthService().authenticate(localizedReason: l10n.sendReviewAuthReason);
    if (!authed) return SendFailed(l10n.sendReviewAuthRequired);

    try {
      final hash = await ref
          .read(transactionSubmissionServiceProvider)
          .balanceTransfer(account, recipient, amount, regularFee.networkFee);
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
}
