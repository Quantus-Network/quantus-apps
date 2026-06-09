import 'package:flutter/foundation.dart';

/// Fee components paid by the proposing member when submitting a transfer
/// proposal.
@immutable
class ProposeFeeBreakdown {
  final BigInt networkFee;
  final BigInt deposit;
  final BigInt creationFee;

  /// On-chain expiry block encoded in the proposal extrinsic.
  final int expiryBlock;

  const ProposeFeeBreakdown({
    required this.networkFee,
    required this.deposit,
    required this.creationFee,
    required this.expiryBlock,
  });

  /// Total out-of-pocket cost for the proposing member at submit time.
  BigInt get memberCost => networkFee + deposit + creationFee;
}
