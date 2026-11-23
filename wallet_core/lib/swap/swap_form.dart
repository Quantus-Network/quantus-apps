import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/swap_providers.dart';

/// The amount [text] types, in base units of the side it is typed on: what
/// [to] receives when it is an [exactOutput], else what [from] pays. Nothing
/// while it is no amount.
BigInt swapTypedAmount(
  NumberFormattingService fmt,
  String text, {
  required SwapToken from,
  required SwapToken to,
  required bool exactOutput,
}) => fmt.parseAmount(text, decimals: (exactOutput ? to : from).decimals) ?? BigInt.zero;

/// What [from] pays and [to] receives: as [quote] prices the amount typed,
/// or until there is one the amount [typed] and the other at listed prices.
(BigInt, BigInt) swapFormAmountsOf({
  required BigInt typed,
  required SwapToken from,
  required SwapToken to,
  required bool exactOutput,
  required SwapQuote? quote,
}) {
  if (quote != null) return (quote.amountIn, quote.amountOut);
  return exactOutput ? (swapEstimateOut(typed, to, from), typed) : (typed, swapEstimateOut(typed, from, to));
}

/// The swap the form describes once it has an amount and the external
/// [address]; null until then. A swap out of QTC refunds to the account's
/// [own] address and pays out at the external one, a swap in the other way.
SwapQuoteRequest? swapQuoteRequestOf({
  required SwapToken from,
  required SwapToken to,
  required bool swapOut,
  required BigInt typed,
  required bool exactOutput,
  required String? address,
  required String own,
  required int slippageBps,
}) {
  if (address == null || typed == BigInt.zero) return null;
  return (
    from: from,
    to: to,
    amount: typed,
    swapType: exactOutput ? SwapType.exactOutput : SwapType.exactInput,
    refundAddress: swapOut ? own : address,
    recipient: swapOut ? address : own,
    slippageBps: slippageBps,
  );
}

/// What the form's button is for.
enum SwapFormStep {
  /// The account cannot pay the amount.
  insufficient,

  /// The external address is still to be given: who is paid, or where a
  /// refund goes.
  addAddress,

  /// The swap can be reviewed.
  review,
}

/// What the form's button does, and whether it can be pressed.
@immutable
class SwapFormAction {
  const SwapFormAction(this.step, {required this.isEnabled});

  final SwapFormStep step;
  final bool isEnabled;
}

/// The form's button for a swap paying [amountIn] and receiving [amountOut].
/// [canPay] is the most the account can put in, or its whole balance until
/// the fee is known; null when the other side pays, and nothing is checked.
/// The address is asked for first, even before an amount; a review needs
/// both amounts.
SwapFormAction swapFormActionOf({
  required BigInt amountIn,
  required BigInt amountOut,
  required BigInt? canPay,
  required bool hasAddress,
}) {
  final insufficient = canPay != null && amountIn > canPay;
  if (insufficient) return const SwapFormAction(SwapFormStep.insufficient, isEnabled: false);
  if (!hasAddress) return const SwapFormAction(SwapFormStep.addAddress, isEnabled: true);
  return SwapFormAction(SwapFormStep.review, isEnabled: amountIn != BigInt.zero && amountOut != BigInt.zero);
}

/// What picking a token changes on the form.
@immutable
class SwapTokenPick {
  const SwapTokenPick({required this.foreign, required this.clearsAddress, required this.flips});

  /// The token now on the other chain's side; null when it stays as it was.
  final SwapToken? foreign;

  /// Whether the external address goes: it was for another network.
  final bool clearsAddress;

  /// Whether the direction turns around.
  final bool flips;
}

/// What picking [picked] for the side [tapped] is on changes, [foreign] being
/// the other chain's token so far; null when it is the token already there.
/// Picking QTC for the other side moves QTC there, as does picking another
/// token for QTC's side.
SwapTokenPick? swapTokenPickOf({required SwapToken tapped, required SwapToken picked, required SwapToken? foreign}) {
  if (picked == tapped) return null;
  return SwapTokenPick(
    foreign: picked.isQuantus ? null : picked,
    clearsAddress: !picked.isQuantus && picked.network != foreign?.network,
    flips: picked.isQuantus != tapped.isQuantus,
  );
}
