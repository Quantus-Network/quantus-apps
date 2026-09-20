import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';

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

  /// Transfer amount this fee priced; zero when unknown or for a max send.
  final BigInt amount;

  /// Priced a `transfer_all`: the chain sizes the amount at inclusion.
  final bool sendAll;

  RegularFee({required this.networkFee, BigInt? amount, this.sendAll = false}) : amount = amount ?? BigInt.zero;

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
enum EncryptedSendBlocker { notQuantized, insufficient }

/// Fee for an encrypted (wormhole) send: the in-circuit volume fee plus
/// quantization dust, carried with the coin-selection [plan] that produced it.
/// When the amount can't be planned, [blocker] says why.
class EncryptedFee extends SendFee {
  final WormholeSpendPlan? plan;
  final EncryptedSendBlocker? blocker;

  const EncryptedFee({this.plan, this.blocker});

  @override
  BigInt get displayFee => plan?.feeToken ?? BigInt.zero;
}

/// What the screens know about a flow's fee right now. [fee] is the latest
/// result and stays put once known; [pending] means a newer query is queued or
/// in flight, [failed] that the latest query failed. Only a [settled] fee is
/// exact; anything else is shown as an estimate.
class SendFeeState {
  final SendFee? fee;
  final bool pending;
  final bool failed;

  const SendFeeState({this.fee, this.pending = false, this.failed = false});

  factory SendFeeState.fromAsync(AsyncValue<SendFee> value) =>
      SendFeeState(fee: value.value, pending: value.isLoading, failed: value.hasError);

  bool get settled => fee != null && !pending && !failed;

  @override
  bool operator ==(Object other) =>
      other is SendFeeState && other.fee == fee && other.pending == pending && other.failed == failed;

  @override
  int get hashCode => Object.hash(fee, pending, failed);
}

/// `ref.read` or `container.read`, so a strategy can be driven from a screen
/// or from the tap that starts the flow.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Prefixes a figure that depends on an unsettled fee with `~`.
String estimateLabel(String text, {required bool estimate}) => estimate ? '~$text' : text;

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
/// flow, which broadcasts and then shows [terminalForHash] built from the
/// submitted extrinsic hash.
class SendNeedsHardwareSignature extends SendOutcome {
  final KeystoneSigningSession session;
  final SendTerminalContent Function(String extrinsicHash) terminalForHash;

  const SendNeedsHardwareSignature({required this.session, required this.terminalForHash});
}

/// Encrypted send authenticated and planned: hand off to the proving progress
/// screen, which generates the ZK proofs, submits and then shows [terminal].
/// [amount] is the confirmed amount; the controller re-checks it against
/// [plan] before proving, since the plan pays exactly its own amountToken.
class SendNeedsProving extends SendOutcome {
  final Account account;
  final WormholeSpendPlan plan;
  final BigInt amount;
  final SendTerminalContent terminal;

  const SendNeedsProving({required this.account, required this.plan, required this.amount, required this.terminal});
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

  /// Amount a flow's first fee query is sized with, before one is entered.
  static final BigInt feeProbeAmount = NumberFormattingService.scaleFactorBigInt;

  /// Whether Max sends the whole spendable balance with `transfer_all`.
  bool get supportsSendAll => false;

  /// Whether the recipient screen shows the "Private Send" notice above the
  /// continue button. Only encrypted (wormhole) sends enable this.
  bool get showPrivateSendNotice => false;

  /// Account the funds leave from; the recipient must differ (self-guard) and
  /// it is excluded from the recents list.
  String? get sourceAccountId;

  /// Self-send guard: whether [address] belongs to the sending account itself.
  /// Defaults to comparing against [sourceAccountId]; encrypted sends also
  /// treat every derived wormhole address of the wallet as self.
  Future<bool> isSelfRecipient(WidgetRef ref, String address) async => address == sourceAccountId;

  SendStrings strings(AppLocalizations l10n);

  /// Balance the amount is drawn from. Used for validation and the Max button.
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider;

  /// Balance shown as "Available Balance" on the amount screen. Defaults to
  /// [spendableBalanceProvider]; encrypted sends override this to show the
  /// total wormhole balance (matching the home screen) while keeping
  /// [spendableBalanceProvider] for validation and Max.
  ProviderListenable<AsyncValue<BigInt>> get displayBalanceProvider => spendableBalanceProvider;

  /// Whether a secondary balance used for gating has no value yet. Watched.
  bool extraBalancesLoading(WidgetRef ref);

  /// Portion of [fee] charged against the spendable balance (drives the
  /// max-sendable calculation and the insufficient-balance check). Zero for
  /// flows where the fee is paid by a different account (e.g. multisig).
  BigInt feeChargedToBalance(SendFee? fee);

  /// Balance of the account that pays the fee, when different from the source.
  /// Returns null for flows where the fee payer is the same as the sender.
  ProviderListenable<AsyncValue<BigInt>>? get feePayerBalanceProvider => null;

  /// Label for the fee payer balance line (e.g. "Your Balance:").
  String? feePayerBalanceLabel(AppLocalizations l10n) => null;

  /// Fee for sending [amount] to [recipient]. Watched by the amount and review
  /// screens; strategies derive it from local state wherever the runtime makes
  /// that possible, otherwise [requestFee] refreshes it from the chain.
  ProviderListenable<SendFeeState> feeProvider({required String recipient, required BigInt amount});

  /// Prices a send of [amount] to [recipient], or of the whole balance when
  /// [sendAll]. Called from event handlers only: the flow-start tap (sized at
  /// [feeProbeAmount]), typing, Max and Continue; [immediate] skips the
  /// debounce. No-op for strategies whose [feeProvider] is derived locally.
  void requestFee(
    ProviderReader read, {
    required String recipient,
    required BigInt amount,
    bool sendAll = false,
    bool immediate = false,
  }) {}

  /// Whether [fee] priced exactly this send: the `transfer_all` call for a max
  /// send, otherwise a transfer of [amount]. Locally derived fees always do.
  bool feeApplies(SendFee fee, {required BigInt amount, required bool sendAll}) => true;

  /// Re-queries whatever source [feeProvider] failed on.
  void retryFee(WidgetRef ref, {required String recipient, required BigInt amount});

  /// Affordability gate beyond `amount <= spendable` (e.g. the proposing member
  /// must cover the proposal cost). Returns an error label, or null when ok or
  /// still loading. Watched in `build`.
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n);

  /// Review-screen summary rows (already spaced). Built in `build`. Figures
  /// that depend on an unsettled [fee] are marked when [feeIsEstimate]; for a
  /// max send ([sendAll]) that is the amount, otherwise the total.
  List<Widget> reviewRows(
    BuildContext context,
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
    bool feeIsEstimate = false,
    bool sendAll = false,
  });

  /// Called while the user is on the review screen (and periodically until it
  /// closes). Strategies that hand off to hardware signing warm the Keystone
  /// sign cache here so the QR screen renders instantly. No-op for flows that
  /// sign locally. Uses `ref.read`.
  Future<void> prefetchSignPayload(
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
    bool sendAll = false,
  }) async {}

  /// Authenticates and submits. Uses `ref.read`. Never navigates. The call is
  /// built from [sendAll], never from what [fee] happened to price.
  Future<SendOutcome> submit(
    WidgetRef ref, {
    required String recipientAddress,
    required String recipientChecksum,
    required BigInt amount,
    required SendFee fee,
    required bool isPayMode,
    bool sendAll = false,
  });
}
