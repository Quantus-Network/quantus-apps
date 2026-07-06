import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/shared/utils/url_utils.dart';
import 'package:resonance_network_wallet/v2/components/detail_summary_row.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Standard single-signer transfer from the active account. Signs locally, or
/// hands off to the Keystone QR flow for hardware accounts.
class RegularSendStrategy extends SendStrategy {
  const RegularSendStrategy();

  static final BigInt _estimateFeeAmount = BigInt.from(1000) * NumberFormattingService.scaleFactorBigInt;

  @override
  String? sourceAccountId(WidgetRef ref) => ref.read(activeAccountProvider).value?.account.accountId;

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
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider => effectiveMaxBalanceProvider;

  @override
  bool extraBalancesLoading(WidgetRef ref) => false;

  @override
  BigInt feeChargedToBalance(SendFee? fee) => (fee as RegularFee?)?.networkFee ?? BigInt.zero;

  @override
  Future<SendFee> estimateFee(WidgetRef ref, {required String recipient, required BigInt amount}) async {
    final displayAccount = ref.read(activeAccountProvider).value;
    if (displayAccount is! RegularAccount) {
      throw StateError('Regular send requires an active regular account');
    }
    final account = displayAccount.account;
    final useReal = amount > BigInt.zero && ref.read(substrateServiceProvider).isValidSS58Address(recipient);
    final feeAmount = useReal ? amount : _estimateFeeAmount;
    final toAddress = useReal ? recipient : account.accountId;
    final feeData = await ref.read(balancesServiceProvider).getBalanceTransferFee(account, toAddress, feeAmount);
    return RegularFee(networkFee: feeData.fee, blockHeight: feeData.blockNumber);
  }

  @override
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n) => null;

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
    final valueStyle = context.themeText.transactionDetailRowLabel;
    final addr = recipientAddress.trim();

    String amt(BigInt v) =>
        l10n.commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);

    return [
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewTo, value: addr, valueStyle: valueStyle),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewAmount, value: amt(amount), valueStyle: valueStyle),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewNetworkFee, value: amt(networkFee), valueStyle: valueStyle),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewYouPay, value: amt(amount + networkFee), valueStyle: valueStyle),
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
    final account = (await SettingsService().getActiveRegularAccount())!;
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
    if (account.accountType == AccountType.keystone || AppConstants.debugHardwareWallet) {
      return SendNeedsHardwareSignature(
        account: account,
        networkFee: regularFee.networkFee,
        blockHeight: regularFee.blockHeight,
        terminal: terminal,
      );
    }

    final authed = await LocalAuthService().authenticate(localizedReason: l10n.sendReviewAuthReason);
    if (!authed) return SendFailed(l10n.sendReviewAuthRequired);

    try {
      final hash = await ref
          .read(transactionSubmissionServiceProvider)
          .balanceTransfer(account, recipient, amount, regularFee.networkFee, regularFee.blockHeight);
      unawaited(
        RecentAddressesService()
            .addAddress(recipient)
            .catchError((Object e) => debugPrint('Failed to save recent address: $e')),
      );
      return SendSubmitted(terminal.copyWith(explorerUrl: explorerImmediateTransactionUrl(hash)));
    } catch (e) {
      debugPrint('Transfer failed: $e');
      return SendFailed(l10n.sendReviewSubmitFailed);
    }
  }
}
