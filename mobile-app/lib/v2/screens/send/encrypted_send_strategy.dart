import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

/// Spend plan — and so the fee — for an amount from the wallet's current
/// UTXO set. Derived from whatever [encryptedStateProvider] holds, including
/// the previous state during a background rescan, so typing never waits on
/// the chain: the volume fee and quantum come from the shipped metadata.
final encryptedSendFeeProvider = Provider.autoDispose.family<AsyncValue<SendFee>, (int walletIndex, BigInt amount)>((
  ref,
  key,
) {
  final (walletIndex, amount) = key;
  return ref.watch(encryptedStateProvider(walletIndex)).whenData<SendFee>((s) => planEncryptedFee(s.utxos, amount));
});

EncryptedFee planEncryptedFee(List<WormholeUtxo> utxos, BigInt amount) {
  if (amount <= BigInt.zero) return const EncryptedFee();
  if (amount % wormholeScaleFactor != BigInt.zero) {
    return const EncryptedFee(blocker: EncryptedSendBlocker.notQuantized);
  }
  try {
    return EncryptedFee(
      plan: selectWormholeInputs(utxos: utxos, amountToken: amount),
    );
  } on InsufficientEncryptedFunds {
    return const EncryptedFee(blocker: EncryptedSendBlocker.insufficient);
  } on BatchBelowMinimumExit {
    return const EncryptedFee(blocker: EncryptedSendBlocker.belowBatchMinimum);
  }
}

/// ZK-private transfer from an encrypted (wormhole) account. Coin selection
/// runs as the fee is derived; submission hands the plan to the proving
/// progress screen via [SendNeedsProving].
class EncryptedSendStrategy extends SendStrategy {
  final Account account;

  const EncryptedSendStrategy({required this.account});

  @override
  bool get showPrivateSendNotice => true;

  @override
  String? sourceAccountId(WidgetRef ref) => account.accountId;

  /// All derived wormhole addresses (receive and change rotate through the HD
  /// sequence) are this account — not just the index-0 [Account.accountId].
  @override
  Future<bool> isSelfRecipient(WidgetRef ref, String address) async {
    if (address == account.accountId) return true;
    return ref.read(encryptedAccountServiceProvider(account.walletIndex)).ownsAddress(address);
  }

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
  ProviderListenable<AsyncValue<BigInt>> get displayBalanceProvider => encryptedBalanceProvider(account.walletIndex);

  @override
  bool extraBalancesLoading(WidgetRef ref) => false;

  @override
  BigInt feeChargedToBalance(SendFee? fee) => BigInt.zero;

  @override
  ProviderListenable<AsyncValue<SendFee>> feeProvider({required String recipient, required BigInt amount}) =>
      encryptedSendFeeProvider((account.walletIndex, amount));

  @override
  void retryFee(WidgetRef ref, {required String recipient, required BigInt amount}) =>
      ref.invalidate(encryptedStateProvider(account.walletIndex));

  @override
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n) {
    return switch ((fee as EncryptedFee).blocker) {
      null => null,
      EncryptedSendBlocker.notQuantized => l10n.encryptedSendAmountStep(AppConstants.tokenSymbol),
      EncryptedSendBlocker.insufficient => l10n.sendLogicInsufficientBalance,
      EncryptedSendBlocker.belowBatchMinimum => l10n.encryptedSendMinimum(AppConstants.tokenSymbol),
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

    String amt(BigInt v) =>
        l10n.commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);

    return [
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewTo, value: recipientAddress.trim()),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewAmount, value: amt(amount)),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.encryptedSendFeeLabel, value: amt(feeAmount)),
      const SizedBox(height: 7),
      DetailSummaryRow.review(label: l10n.sendReviewYouPay, value: amt(amount + feeAmount)),
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
    // The plan is frozen at estimate time and its amountToken is what the
    // recipient is provably paid — it must match the confirmed amount.
    if (plan.amountToken != amount) {
      throw StateError('Encrypted send plan amount ${plan.amountToken} does not match confirmed amount $amount');
    }

    final authed = await LocalAuthService().authenticate(localizedReason: l10n.sendReviewAuthReason);
    if (!authed) return SendFailed(l10n.sendReviewAuthRequired);

    return SendNeedsProving(
      account: account,
      plan: plan,
      amount: amount,
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
