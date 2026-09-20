import 'package:quantus_sdk/src/models/swap_token.dart';

/// A 1Click quote. Amounts are base units of their token. [depositAddress] is
/// only set on a live (non-dry) quote; funds sent there before [deadline] are
/// swapped, anything else is refunded to [refundAddress].
class SwapQuote {
  final SwapToken fromToken;
  final SwapToken toToken;
  final BigInt amountIn;
  final BigInt amountOut;
  final BigInt minAmountOut;
  final double amountInUsd;
  final double amountOutUsd;
  final int slippageBps;
  final String refundAddress;
  final String recipient;
  final DateTime deadline;
  final Duration timeEstimate;
  final String correlationId;
  final String? depositAddress;
  final String? depositMemo;

  const SwapQuote({
    required this.fromToken,
    required this.toToken,
    required this.amountIn,
    required this.amountOut,
    required this.minAmountOut,
    required this.amountInUsd,
    required this.amountOutUsd,
    required this.slippageBps,
    required this.refundAddress,
    required this.recipient,
    required this.deadline,
    required this.timeEstimate,
    required this.correlationId,
    this.depositAddress,
    this.depositMemo,
  });

  factory SwapQuote.fromJson(Map<String, dynamic> json, {required SwapToken fromToken, required SwapToken toToken}) {
    final quote = json['quote'] as Map<String, dynamic>;
    final request = json['quoteRequest'] as Map<String, dynamic>;
    return SwapQuote(
      fromToken: fromToken,
      toToken: toToken,
      amountIn: BigInt.parse(quote['amountIn'] as String),
      amountOut: BigInt.parse(quote['amountOut'] as String),
      minAmountOut: BigInt.parse(quote['minAmountOut'] as String),
      amountInUsd: double.parse(quote['amountInUsd'] as String),
      amountOutUsd: double.parse(quote['amountOutUsd'] as String),
      slippageBps: (request['slippageTolerance'] as num).toInt(),
      refundAddress: request['refundTo'] as String,
      recipient: request['recipient'] as String,
      deadline: DateTime.parse((quote['deadline'] ?? request['deadline']) as String),
      timeEstimate: Duration(seconds: (quote['timeEstimate'] as num).round()),
      correlationId: json['correlationId'] as String,
      depositAddress: quote['depositAddress'] as String?,
      depositMemo: quote['depositMemo'] as String?,
    );
  }
}
