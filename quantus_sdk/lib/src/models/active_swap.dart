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

  /// When a poll first found the order past PENDING_DEPOSIT, by this
  /// device's clock. 1Click's time estimate runs from here.
  final DateTime? depositSeenAt;

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
    this.depositSeenAt,
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

  /// Whether 1Click still waits for a deposit by hand the user has not said
  /// is out: the swap is only paid from its deposit screen.
  bool get awaitingDeposit => order.status == SwapStatus.pendingDeposit && !depositUnderway;

  /// Whether the swap is with 1Click and expected to settle: its deposit was
  /// seen there or is on its way, and it is neither settled nor overdue.
  bool inProgressAt(DateTime now) => !isFinal && !overdue(now) && !awaitingDeposit;

  Duration elapsedAt(DateTime now) => (settledAt ?? now).difference(startedAt);

  /// How long past its deposit deadline a swap may take to settle before it
  /// counts as overdue: a deposit sent near the deadline can be seen late,
  /// and 1Click starts a refund at the deadline. Senoti stops polling at the
  /// same point.
  static const finishGrace = Duration(minutes: 10);

  /// Whether the swap should have settled by now: it is not settled
  /// [finishGrace] past its deadline. Its status is no longer polled then.
  bool overdue(DateTime now) => !isFinal && now.isAfter(order.quote.deadline.add(finishGrace));

  ActiveSwap withOrder(SwapOrder order, {required DateTime now}) => _copy(
    order: order,
    settledAt: order.status.isFinal ? now : null,
    pollError: null,
    depositSeenAt: depositSeenAt ?? (order.status == SwapStatus.pendingDeposit ? null : now),
  );

  ActiveSwap withPollError(String error) => _copy(order: order, settledAt: settledAt, pollError: error);

  ActiveSwap withDepositSent() => _copy(order: order, settledAt: settledAt, pollError: pollError, depositSent: true);

  ActiveSwap _copy({
    required SwapOrder order,
    required DateTime? settledAt,
    required String? pollError,
    bool? depositSent,
    DateTime? depositSeenAt,
  }) => ActiveSwap(
    order: order,
    accountId: accountId,
    accountName: accountName,
    startedAt: startedAt,
    settledAt: settledAt,
    depositSeenAt: depositSeenAt ?? this.depositSeenAt,
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
    final depositSeenAt = json['depositSeenAt'] as String?;
    final depositFee = json['depositFee'] as String?;
    return ActiveSwap(
      order: SwapOrder.fromStatusJson(json['status'] as Map<String, dynamic>, quote: quote),
      accountId: json['accountId'] as String,
      accountName: json['accountName'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      settledAt: settledAt == null ? null : DateTime.parse(settledAt),
      depositSeenAt: depositSeenAt == null ? null : DateTime.parse(depositSeenAt),
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
    'depositSeenAt': ?depositSeenAt?.toUtc().toIso8601String(),
    'depositByHand': depositByHand,
    'depositSent': depositSent,
    'depositTxHash': ?depositTxHash,
    'depositFee': ?depositFee?.toString(),
  };
}
