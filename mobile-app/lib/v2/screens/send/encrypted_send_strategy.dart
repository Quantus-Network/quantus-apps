import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/v2/components/detail_summary_row.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// ZK-private transfer from an encrypted (wormhole) account. Coin selection
/// runs during fee estimation; submission hands the plan to the proving
/// progress screen via [SendNeedsProving].
class EncryptedSendStrategy extends SendStrategy {
  final Account account;

  const EncryptedSendStrategy({required this.account});

  @override
  String? sourceAccountId(WidgetRef ref) => account.accountId;

  @override
  SendStrings strings(AppLocalizations l10n) => SendStrings(
    flowTitle: l10n.sendTitle,
    recipientSectionLabel: l10n.sendSelectRecipientSendTo,
    amountRecipientCardLabel: l10n.sendInputAmountSendTo,
    feeLabel: l10n.encryptedSendFeeLabel,
    feeFetchFailedMessage: l10n.multisigProposeFeeFetchFailed,
    reviewButtonLabel: l10n.sendLogicReviewSend,
    reviewHeroLabel: l10n.sendReviewSending,
    reviewConfirmLabel: l10n.sendReviewConfirm,
  );

  @override
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider =>
      encryptedSpendableProvider(account.walletIndex);

  @override
  bool extraBalancesLoading(WidgetRef ref) => false;

  /// The volume fee comes out of the consumed inputs, not on top of the
  /// spendable amount ([spendableBalanceProvider] is already net of it).
  @override
  BigInt feeChargedToBalance(SendFee? fee) => BigInt.zero;

  @override
  Future<SendFee> estimateFee(WidgetRef ref, {required String recipient, required BigInt amount}) async {
    if (amount <= BigInt.zero) return const EncryptedFee();
    if (amount % wormholeScaleFactor != BigInt.zero) {
      return const EncryptedFee(blocker: EncryptedSendBlocker.notQuantized);
    }
    final state = await ref.read(encryptedStateProvider(account.walletIndex).future);
    try {
      return EncryptedFee(plan: selectWormholeInputs(utxos: state.utxos, amountPlanck: amount));
    } on InsufficientEncryptedFunds {
      return const EncryptedFee(blocker: EncryptedSendBlocker.insufficient);
    } on BatchBelowMinimumExit {
      return const EncryptedFee(blocker: EncryptedSendBlocker.belowBatchMinimum);
    }
  }

  @override
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n) {
    return switch ((fee as EncryptedFee).blocker) {
      null => null,
      EncryptedSendBlocker.notQuantized => l10n.encryptedSendAmountStep,
      EncryptedSendBlocker.insufficient => l10n.sendLogicInsufficientBalance,
      EncryptedSendBlocker.belowBatchMinimum => l10n.encryptedSendMinimum,
    };
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
    final feeAmount = fee.displayFee;
    final valueStyle = context.themeText.transactionDetailRowLabel;

    String amt(BigInt v) =>
        l10n.commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);

    return [
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewTo, value: recipientAddress.trim(), valueStyle: valueStyle),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewAmount, value: amt(amount), valueStyle: valueStyle),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.encryptedSendFeeLabel, value: amt(feeAmount), valueStyle: valueStyle),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewYouPay, value: amt(amount + feeAmount), valueStyle: valueStyle),
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
    final plan = (fee as EncryptedFee).plan;
    if (plan == null) {
      throw StateError('Encrypted send reached submit without a spend plan');
    }

    final authed = await LocalAuthService().authenticate(localizedReason: l10n.sendReviewAuthReason);
    if (!authed) return SendFailed(l10n.sendReviewAuthRequired);

    return SendNeedsProving(
      account: account,
      plan: plan,
      terminal: buildSentTerminalContent(
        l10n,
        ref.read(numberFormattingServiceProvider),
        recipient: recipientAddress.trim(),
        checksum: recipientChecksum,
        amount: amount,
        isPayMode: isPayMode,
      ),
    );
  }
}
