import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

/// Per-step labels that differ between the send flows (regular transfer vs
/// multisig proposal). Built once from [AppLocalizations] by each strategy so
/// the shared screens never branch on the flow type.
class SendStrings {
  final String flowTitle;
  final String recipientSectionLabel;
  final String amountRecipientCardLabel;
  final String feeLabel;
  final String feeFetchFailedMessage;
  final String reviewButtonLabel;
  final String reviewHeroLabel;
  final String reviewConfirmLabel;

  const SendStrings({
    required this.flowTitle,
    required this.recipientSectionLabel,
    required this.amountRecipientCardLabel,
    required this.feeLabel,
    required this.feeFetchFailedMessage,
    required this.reviewButtonLabel,
    required this.reviewHeroLabel,
    required this.reviewConfirmLabel,
  });
}

/// Fee for a send. The shared screens only read [displayFee]; each strategy
/// keeps its concrete payload for submission.
sealed class SendFee {
  const SendFee();

  BigInt get displayFee;
}

class RegularFee extends SendFee {
  final BigInt networkFee;
  final int blockHeight;

  const RegularFee({required this.networkFee, required this.blockHeight});

  @override
  BigInt get displayFee => networkFee;
}

class ProposeFee extends SendFee {
  final ProposeFeeBreakdown breakdown;

  const ProposeFee(this.breakdown);

  @override
  BigInt get displayFee => breakdown.memberCost;
}

/// Why an encrypted send can't be built for the entered amount.
enum EncryptedSendBlocker { notQuantized, insufficient, belowBatchMinimum }

/// Fee for an encrypted (wormhole) send: the in-circuit volume fee plus
/// quantization dust, carried with the coin-selection [plan] that produced it.
/// When the amount can't be planned, [blocker] says why.
class EncryptedFee extends SendFee {
  final WormholeSpendPlan? plan;
  final EncryptedSendBlocker? blocker;

  const EncryptedFee({this.plan, this.blocker});

  @override
  BigInt get displayFee => plan?.feePlanck ?? BigInt.zero;
}

/// Content for the shared terminal (success) screen. All strings are resolved
/// up front so it can be built without a [BuildContext].
class SendTerminalContent {
  final String title;
  final String headline;
  final String subline;
  final String? amountText;
  final String recipientAddress;
  final String? recipientChecksum;
  final String? signaturesLabel;
  final String doneLabel;
  final double topSpacing;

  /// Block-explorer URL for the submitted transaction. Null until a hash is
  /// available (e.g. multisig proposals, or before a Keystone signature).
  final String? explorerUrl;

  const SendTerminalContent({
    required this.title,
    required this.headline,
    required this.subline,
    required this.recipientAddress,
    required this.recipientChecksum,
    required this.doneLabel,
    this.amountText,
    this.signaturesLabel,
    this.topSpacing = 0,
    this.explorerUrl,
  });

  SendTerminalContent copyWith({String? explorerUrl}) => SendTerminalContent(
    title: title,
    headline: headline,
    subline: subline,
    recipientAddress: recipientAddress,
    recipientChecksum: recipientChecksum,
    doneLabel: doneLabel,
    amountText: amountText,
    signaturesLabel: signaturesLabel,
    topSpacing: topSpacing,
    explorerUrl: explorerUrl ?? this.explorerUrl,
  );
}

/// Result of [SendStrategy.submit].
sealed class SendOutcome {
  const SendOutcome();
}

/// Submission accepted; show [terminal].
class SendSubmitted extends SendOutcome {
  final SendTerminalContent terminal;

  const SendSubmitted(this.terminal);
}

/// The source account signs off-device (Keystone): hand off to the hardware QR
/// flow, which broadcasts and then shows [terminal].
class SendNeedsHardwareSignature extends SendOutcome {
  final Account account;
  final BigInt networkFee;
  final int blockHeight;
  final SendTerminalContent terminal;

  const SendNeedsHardwareSignature({
    required this.account,
    required this.networkFee,
    required this.blockHeight,
    required this.terminal,
  });
}

/// Encrypted send authenticated and planned: hand off to the proving progress
/// screen, which generates the ZK proofs, submits and then shows [terminal].
class SendNeedsProving extends SendOutcome {
  final Account account;
  final WormholeSpendPlan plan;
  final SendTerminalContent terminal;

  const SendNeedsProving({required this.account, required this.plan, required this.terminal});
}

/// Submission failed or was not authenticated; show [message] inline.
class SendFailed extends SendOutcome {
  final String message;

  const SendFailed(this.message);
}

/// Terminal content for a completed transfer, shared by the flows that send a
/// fixed amount to one recipient (regular and encrypted sends).
SendTerminalContent buildSentTerminalContent(
  AppLocalizations l10n,
  NumberFormattingService fmt, {
  required String recipient,
  required String checksum,
  required BigInt amount,
  required bool isPayMode,
}) {
  final n = fmt.formatBalance(amount, smartDecimals: 4);
  return SendTerminalContent(
    title: isPayMode ? l10n.sendPayTitle : l10n.sendTitle,
    headline: isPayMode
        ? l10n.sendTxSubmittedHeadlinePaid(n, AppConstants.tokenSymbol)
        : l10n.sendTxSubmittedHeadlineSent(n, AppConstants.tokenSymbol),
    subline: l10n.sendTxSubmittedOnItsWay,
    recipientAddress: recipient,
    recipientChecksum: checksum,
    doneLabel: l10n.sendTxSubmittedDone,
    topSpacing: 70,
  );
}

/// Encapsulates everything that differs between the send and multisig-propose
/// flows so the recipient, amount, review and terminal screens can be shared.
abstract class SendStrategy {
  const SendStrategy();

  /// Account the funds leave from; the recipient must differ (self-guard) and
  /// it is excluded from the recents list. Resolved via `ref.read`.
  String? sourceAccountId(WidgetRef ref);

  SendStrings strings(AppLocalizations l10n);

  /// Balance the amount is drawn from. Exposed as a provider so the amount
  /// screen can watch it in `build` and read it in event handlers.
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider;

  /// Whether a secondary balance used for gating is still loading. Watched.
  bool extraBalancesLoading(WidgetRef ref);

  /// Portion of [fee] charged against the spendable balance (drives the
  /// max-sendable calculation and the insufficient-balance check). Zero for
  /// flows where the fee is paid by a different account (e.g. multisig).
  BigInt feeChargedToBalance(SendFee? fee);

  /// Estimates the fee for [amount] to [recipient]. Uses `ref.read`. Handles
  /// the zero/invalid-amount estimate internally.
  Future<SendFee> estimateFee(WidgetRef ref, {required String recipient, required BigInt amount});

  /// Affordability gate beyond `amount <= spendable` (e.g. the proposing member
  /// must cover the proposal cost). Returns an error label, or null when ok or
  /// still loading. Watched in `build`.
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n);

  /// Review-screen summary rows (already spaced). Built in `build`.
  List<Widget> reviewRows(
    BuildContext context,
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
  });

  /// Authenticates and submits. Uses `ref.read`. Never navigates.
  Future<SendOutcome> submit(
    WidgetRef ref, {
    required String recipientAddress,
    required String recipientChecksum,
    required BigInt amount,
    required SendFee fee,
    required bool isPayMode,
  });
}
