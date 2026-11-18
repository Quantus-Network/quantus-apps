import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_review.dart';
import 'package:wallet_core/send/send_screen_logic.dart';
import 'package:wallet_core/send/send_strategy.dart';

import '../fakes.dart';

/// [tokens] in the chain's smallest unit; thousandths of a token are exact.
BigInt _qtc(num tokens) =>
    BigInt.from((tokens * 1000).round()) * NumberFormattingService.scaleFactorBigInt ~/ BigInt.from(1000);

void main() {
  final strategy = RegularSendStrategy(account: makeAccount(1));

  SendReview review({
    required SendFeeState feeState,
    required num? spendable,
    required num entered,
    bool sendAll = false,
    num openedWithFee = 1,
  }) => SendReview.of(
    strategy,
    feeState: feeState,
    openedWith: RegularFee(networkFee: _qtc(openedWithFee)),
    spendable: spendable == null ? null : _qtc(spendable),
    enteredAmount: _qtc(entered),
    sendAll: sendAll,
  );

  SendFeeState settled(num fee, {num? forAmount, bool sendAll = false}) => SendFeeState(
    fee: RegularFee(networkFee: _qtc(fee), amount: forAmount == null ? null : _qtc(forAmount), sendAll: sendAll),
  );

  test('a send with room for another fee is not held up by a fee priced for a different amount', () {
    final r = review(feeState: settled(1, forAmount: 4), spendable: 100, entered: 5);

    expect(r.feeApplies, isFalse);
    expect(r.waitingForFee, isFalse);
    expect(r.confirmBlocked, isFalse);
    expect(r.amount, _qtc(5));
  });

  test('a send within one more fee of the balance waits for the fee of exactly its amount', () {
    final estimated = review(feeState: settled(1, forAmount: 4), spendable: 10, entered: 8.5);
    final exact = review(feeState: settled(1, forAmount: 8.5), spendable: 10, entered: 8.5);

    expect(estimated.waitingForFee, isTrue);
    expect(estimated.confirmBlocked, isTrue);
    expect(exact.feeApplies, isTrue);
    expect(exact.confirmBlocked, isFalse);
  });

  test('a fee still being asked for is not exact, whatever it priced', () {
    final r = review(
      feeState: SendFeeState(
        fee: RegularFee(networkFee: _qtc(1), amount: _qtc(8.5)),
        pending: true,
      ),
      spendable: 10,
      entered: 8.5,
    );

    expect(r.feeApplies, isFalse);
    expect(r.confirmBlocked, isTrue);
  });

  test('a max send waits for the fee of sending everything, and pays the balance less that fee', () {
    final estimated = review(feeState: settled(1, forAmount: 9), spendable: 10, entered: 9, sendAll: true);
    final exact = review(feeState: settled(2, sendAll: true), spendable: 10, entered: 9, sendAll: true);

    expect(estimated.amount, _qtc(9));
    expect(estimated.confirmBlocked, isTrue);
    expect(exact.amount, _qtc(8));
    expect(exact.feeApplies, isTrue);
    expect(exact.confirmBlocked, isFalse);
  });

  test('the fee the review opened with stands in until the flow has one', () {
    final r = review(feeState: const SendFeeState(pending: true), spendable: 10, entered: 9, sendAll: true);

    expect(r.fee.displayFee, _qtc(1));
    expect(r.amount, _qtc(9));
  });

  test('a max send that its fee leaves below the minimum is blocked', () {
    final r = review(feeState: settled(1, sendAll: true), spendable: 1.005, entered: 0.005, sendAll: true);

    expect(r.amountStatus, AmountStatus.belowMinimum);
    expect(r.confirmBlocked, isTrue);
  });

  test('a balance that fell under the amount and its fee blocks the send', () {
    final r = review(feeState: settled(1, forAmount: 5), spendable: 3, entered: 5);

    expect(r.amountStatus, AmountStatus.insufficientBalance);
    expect(r.confirmBlocked, isTrue);
  });

  test('a balance that is not known keeps the amount as entered and blocks the send', () {
    final r = review(feeState: settled(1, sendAll: true), spendable: null, entered: 5, sendAll: true);

    expect(r.amount, _qtc(5));
    expect(r.confirmBlocked, isTrue);
  });

  test('says the fee failed only while the send waits for it', () {
    const failed = SendFeeState(failed: true);

    expect(review(feeState: failed, spendable: 10, entered: 9, sendAll: true).feeFailed, isTrue);
    expect(review(feeState: failed, spendable: 100, entered: 5).feeFailed, isFalse);
  });
}
