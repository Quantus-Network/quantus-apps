import 'package:quantus_sdk/src/models/swap_order.dart';
import 'package:quantus_sdk/src/models/swap_quote.dart';
import 'package:quantus_sdk/src/models/swap_token.dart';

/// A swap the app is following: its live order from the moment it is
/// confirmed until the user puts it away. Several can be followed at once,
/// told apart by [id].
class ActiveSwap {
  final SwapOrder order;
  final String accountId;
  final String accountName;
  final DateTime startedAt;

  /// When the order reached a final status; the timer stops there.
  final DateTime? settledAt;

  /// Whether the user makes the deposit from another wallet, rather than the
  /// app sending it from the account.
  final bool depositByHand;

  /// Whether the user has said a deposit by hand is out, so the swap is
  /// followed as sent rather than still waiting to be paid.
  final bool depositSent;

  /// Hash and fee of the QTC transfer that paid the deposit, when the app sent it.
  final String? depositTxHash;
  final BigInt? depositFee;

  /// Why the last status poll failed; null once one succeeds.
  final String? pollError;

  /// A swap the debug harness drives: neither polled nor persisted.
  final bool simulated;

  const ActiveSwap({
    required this.order,
    required this.accountId,
    required this.accountName,
    required this.startedAt,
    required this.depositByHand,
    this.depositSent = false,
    this.settledAt,
    this.depositTxHash,
    this.depositFee,
    this.pollError,
    this.simulated = false,
  });

  /// What tells the swap apart: its deposit address, with the memo where
  /// the chain needs one. 1Click never hands the same address out twice.
  String get id {
    final memo = order.quote.depositMemo;
    return memo == null ? order.depositAddress : '${order.depositAddress}#$memo';
  }

  bool get isFinal => order.status.isFinal;

  /// Whether the deposit is on its way to 1Click: sent by the app, or sent
  /// by hand and marked so.
  bool get depositUnderway => !depositByHand || depositSent;

  /// Whether the swap is with 1Click and expected to settle: its deposit was
  /// seen there or is on its way, and it is neither settled nor overdue.
  bool inProgressAt(DateTime now) =>
      !isFinal && !overdue(now) && (order.status != SwapStatus.pendingDeposit || depositUnderway);

  Duration elapsedAt(DateTime now) => (settledAt ?? now).difference(startedAt);

  /// The deposit window closed with 1Click still waiting for the deposit.
  /// How long past its deposit deadline a swap whose deposit 1Click has seen
  /// may take to settle before it counts as overdue.
  static const finishGrace = Duration(hours: 1);

  /// Whether the swap should have settled by now: its deposit was not seen
  /// by the deadline, or it was seen and the swap is not settled an hour
  /// past that.
  bool overdue(DateTime now) =>
      !isFinal &&
      now.isAfter(order.quote.deadline.add(order.status == SwapStatus.pendingDeposit ? Duration.zero : finishGrace));

  ActiveSwap withOrder(SwapOrder order, {required DateTime now}) =>
      _copy(order: order, settledAt: order.status.isFinal ? now : null, pollError: null);

  ActiveSwap withPollError(String error) => _copy(order: order, settledAt: settledAt, pollError: error);

  ActiveSwap withDepositSent() => _copy(order: order, settledAt: settledAt, pollError: pollError, depositSent: true);

  ActiveSwap _copy({
    required SwapOrder order,
    required DateTime? settledAt,
    required String? pollError,
    bool? depositSent,
  }) => ActiveSwap(
    order: order,
    accountId: accountId,
    accountName: accountName,
    startedAt: startedAt,
    settledAt: settledAt,
    depositByHand: depositByHand,
    depositSent: depositSent ?? this.depositSent,
    depositTxHash: depositTxHash,
    depositFee: depositFee,
    pollError: pollError,
    simulated: simulated,
  );

  factory ActiveSwap.fromJson(Map<String, dynamic> json) {
    final from = SwapToken.fromJson(json['fromToken'] as Map<String, dynamic>);
    final to = SwapToken.fromJson(json['toToken'] as Map<String, dynamic>);
    final quote = SwapQuote.fromJson(json['quote'] as Map<String, dynamic>, fromToken: from, toToken: to);
    final settledAt = json['settledAt'] as String?;
    final depositFee = json['depositFee'] as String?;
    return ActiveSwap(
      order: SwapOrder.fromStatusJson(json['status'] as Map<String, dynamic>, quote: quote),
      accountId: json['accountId'] as String,
      accountName: json['accountName'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      settledAt: settledAt == null ? null : DateTime.parse(settledAt),
      depositByHand: json['depositByHand'] as bool,
      depositSent: json['depositSent'] as bool? ?? false,
      depositTxHash: json['depositTxHash'] as String?,
      depositFee: depositFee == null ? null : BigInt.parse(depositFee),
    );
  }

  Map<String, dynamic> toJson() => {
    'fromToken': order.quote.fromToken.toJson(),
    'toToken': order.quote.toToken.toJson(),
    'quote': order.quote.toJson(),
    'status': order.toJson(),
    'accountId': accountId,
    'accountName': accountName,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'settledAt': ?settledAt?.toUtc().toIso8601String(),
    'depositByHand': depositByHand,
    'depositSent': depositSent,
    'depositTxHash': ?depositTxHash,
    'depositFee': ?depositFee?.toString(),
  };
}
