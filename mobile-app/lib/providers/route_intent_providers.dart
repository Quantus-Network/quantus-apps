import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final transactionIntentProvider = StateProvider<TransactionEvent?>((_) => null);
final sharedAccountIntentProvider = StateProvider<String?>((_) => null);

/// A request to open a specific multisig proposal, typically from a push
/// notification tap. Carries only the identifiers needed to resolve the
/// owning multisig account and fetch the live proposal.
class ProposalIntent {
  final String multisigAddress;
  final int proposalId;

  const ProposalIntent({required this.multisigAddress, required this.proposalId});

  /// Parses an FCM data payload of the form `{multisig: string, proposalId: number}`.
  ///
  /// FCM delivers data values as strings, so [proposalId] is accepted as either
  /// a string or a number. Returns null when the payload is malformed.
  static ProposalIntent? tryParse(Map<String, dynamic> json) {
    final multisig = json['multisig'];
    if (multisig is! String || multisig.isEmpty) return null;

    final proposalId = switch (json['proposalId']) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    };
    if (proposalId == null) return null;

    return ProposalIntent(multisigAddress: multisig, proposalId: proposalId);
  }
}

final proposalIntentProvider = StateProvider<ProposalIntent?>((_) => null);

class PaymentIntent {
  final String to;
  final String amount;
  final String? ref;

  const PaymentIntent({required this.to, required this.amount, this.ref});

  static PaymentIntent? tryParseUrl(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null || uri.pathSegments.isEmpty || uri.pathSegments.first != 'pay') return null;
    final to = uri.queryParameters['to'];
    final amount = uri.queryParameters['amount'];
    if (to == null || to.isEmpty || amount == null || amount.isEmpty) return null;
    return PaymentIntent(to: to, amount: amount, ref: uri.queryParameters['ref']);
  }
}

final paymentIntentProvider = StateProvider<PaymentIntent?>((_) => null);
