import 'package:flutter/foundation.dart';
import 'package:wallet_core/send/send_screen_logic.dart';
import 'package:wallet_core/send/send_strategy.dart';

/// What a review knows about the send it is about to confirm, worked out
/// from the flow's fee and the balance as they stand now: both can move while
/// the review is open.
@immutable
class SendReview {
  const SendReview._({
    required this.fee,
    required this.amount,
    required this.feeApplies,
    required this.waitingForFee,
    required this.feeFailed,
    required this.amountStatus,
  });

  /// [openedWith] is the fee the review opened with, which stands in until
  /// [feeState] has one. [enteredAmount] is what was typed; a max send
  /// ([sendAll]) pays what the fee leaves of [spendable] instead. A
  /// [spendable] of null is a balance not known yet.
  factory SendReview.of(
    SendStrategy strategy, {
    required SendFeeState feeState,
    required SendFee openedWith,
    required BigInt? spendable,
    required BigInt enteredAmount,
    required bool sendAll,
  }) {
    final fee = feeState.fee ?? openedWith;
    final feeCharged = strategy.feeChargedToBalance(fee);
    final amount = !sendAll || spendable == null
        ? enteredAmount
        : SendScreenLogic.calculateMaxSendableAmount(balance: spendable, networkFee: feeCharged);
    final feeApplies = feeState.settled && strategy.feeApplies(fee, amount: amount, sendAll: sendAll);
    // A max send is sized by its fee. An ordinary send only needs its exact
    // fee when the amount leaves less than one more fee of headroom: a quote
    // for a nearby amount differs from the exact fee by a few bytes' worth,
    // far less than a whole fee, so anything with that headroom cannot fail
    // on the fee.
    final needsExactFee = sendAll || (spendable != null && amount + feeCharged * BigInt.two > spendable);
    final waitingForFee = needsExactFee && !feeApplies;

    return SendReview._(
      fee: fee,
      amount: amount,
      feeApplies: feeApplies,
      waitingForFee: waitingForFee,
      feeFailed: waitingForFee && feeState.failed,
      // Checked again here because a max amount follows the settled fee and
      // can fall below the minimum, and the balance can move.
      amountStatus: SendScreenLogic.getAmountStatus(amount, spendable ?? BigInt.zero, feeCharged),
    );
  }

  /// The latest fee the flow has.
  final SendFee fee;

  /// What the send pays the recipient.
  final BigInt amount;

  /// The settled fee priced exactly this send.
  final bool feeApplies;

  /// The send needs its exact fee and does not have it yet.
  final bool waitingForFee;

  /// The fee the send waits for could not be had.
  final bool feeFailed;

  final AmountStatus amountStatus;

  bool get confirmBlocked => waitingForFee || amountStatus != AmountStatus.valid;
}
