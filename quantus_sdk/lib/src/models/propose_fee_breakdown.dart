import 'package:flutter/foundation.dart';

/// Fee components paid by the proposing member when submitting a transfer
/// proposal.
@immutable
class ProposeFeeBreakdown {
  final BigInt networkFee;
  final BigInt deposit;
  final BigInt creationFee;

  const ProposeFeeBreakdown({
    required this.networkFee,
    required this.deposit,
    required this.creationFee,
  });

  /// Total out-of-pocket cost for the proposing member at submit time.
  BigInt get memberCost => networkFee + deposit + creationFee;
}
