import 'package:quantus_sdk/quantus_sdk.dart';

/// The swap the app is following: its live order from the moment it is
/// confirmed until the user puts it away. At most one at a time.
class ActiveSwap {
  /// How long an unsettled swap may run before the user may put it away and
  /// start another, assuming it did not work.
  static const staleAfter = Duration(minutes: 10);

  final SwapOrder order;
  final String accountId;
  final String accountName;
  final DateTime startedAt;

  /// When the order reached a final status; the timer stops there.
  final DateTime? settledAt;

  /// Whether the user makes the deposit from another wallet, rather than the
  /// app sending it from the account.
  final bool depositByHand;

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
    this.settledAt,
    this.depositTxHash,
    this.depositFee,
    this.pollError,
    this.simulated = false,
  });

  bool get isFinal => order.status.isFinal;

  Duration elapsedAt(DateTime now) => (settledAt ?? now).difference(startedAt);

  /// Unsettled for longer than [staleAfter].
  bool isStale(DateTime now) => !isFinal && now.difference(startedAt) >= staleAfter;

  /// The deposit window closed with 1Click still waiting for the deposit.
  bool deadlinePassed(DateTime now) => order.status == SwapStatus.pendingDeposit && now.isAfter(order.quote.deadline);

  ActiveSwap withOrder(SwapOrder order, {required DateTime now}) =>
      _copy(order: order, settledAt: order.status.isFinal ? now : null, pollError: null);

  ActiveSwap withPollError(String error) => _copy(order: order, settledAt: settledAt, pollError: error);

  ActiveSwap _copy({required SwapOrder order, required DateTime? settledAt, required String? pollError}) => ActiveSwap(
    order: order,
    accountId: accountId,
    accountName: accountName,
    startedAt: startedAt,
    settledAt: settledAt,
    depositByHand: depositByHand,
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
    'depositTxHash': ?depositTxHash,
    'depositFee': ?depositFee?.toString(),
  };
}
