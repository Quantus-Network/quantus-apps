import 'package:quantus_sdk/src/models/swap_quote.dart';

enum SwapStatus {
  pendingDeposit('PENDING_DEPOSIT'),
  knownDepositTx('KNOWN_DEPOSIT_TX'),
  incompleteDeposit('INCOMPLETE_DEPOSIT'),
  processing('PROCESSING'),
  success('SUCCESS'),
  refunded('REFUNDED'),
  failed('FAILED');

  const SwapStatus(this.wire);
  final String wire;

  bool get isFinal => this == success || this == refunded || this == failed;

  static SwapStatus parse(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => throw FormatException('Unknown swap status: $wire'));
}

/// A live quote plus what 1Click has reported about it so far.
class SwapOrder {
  final SwapQuote quote;
  final SwapStatus status;
  final BigInt? amountOut;
  final BigInt? refundedAmount;
  final String? refundReason;
  final List<String> destinationTxHashes;

  const SwapOrder({
    required this.quote,
    required this.status,
    this.amountOut,
    this.refundedAmount,
    this.refundReason,
    this.destinationTxHashes = const [],
  });

  String get depositAddress => quote.depositAddress!;

  factory SwapOrder.fromStatusJson(Map<String, dynamic> json, {required SwapQuote quote}) {
    final details = json['swapDetails'] as Map<String, dynamic>?;
    BigInt? amount(String key) {
      final raw = details?[key] as String?;
      return raw == null || raw.isEmpty ? null : BigInt.parse(raw);
    }

    final destination = details?['destinationChainTxHashes'] as List<dynamic>? ?? const [];
    return SwapOrder(
      quote: quote,
      status: SwapStatus.parse(json['status'] as String),
      amountOut: amount('amountOut'),
      refundedAmount: amount('refundedAmount'),
      refundReason: details?['refundReason'] as String?,
      destinationTxHashes: [for (final tx in destination) (tx as Map<String, dynamic>)['hash'] as String],
    );
  }
}
