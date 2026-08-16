import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final transactionIntentProvider = StateProvider<TransactionEvent?>((_) => null);
final sharedAccountIntentProvider = StateProvider<String?>((_) => null);

/// Intent to open the Accounts popup after returning Home. When
/// [highlightAccountId] is set, that account is pre-selected (highlighted, not
/// activated); otherwise the active account is scrolled into view. Drained by
/// [HomeScreen].
class OpenAccountsIntent {
  final String? highlightAccountId;
  const OpenAccountsIntent({this.highlightAccountId});
}

final openAccountsIntentProvider = StateProvider<OpenAccountsIntent?>((_) => null);

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

/// Inbound caps for anything arriving via deep link or QR code. A maximal
/// legitimate /pay link is ~180 chars (host + path, ~50-char SS58 address,
/// NNNNNNNN.NNNNNNNNNNNN amount, 64-char ref), so 256 for the whole URL
/// leaves headroom while keeping every parsed value bounded.
const int maxDeepLinkLength = 256;
const int maxAddressLength = 64;
const int maxPaymentRefLength = 64;

/// [Uri.pathSegments] and [Uri.queryParameters] percent-decode lazily and throw
/// [FormatException] on malformed escapes (`%c3%28`), which [Uri.tryParse]
/// happily accepts. Every read of an external link goes through this
/// fail-closed accessor so the throw can't escape into a stream listener or a
/// barcode callback.
({List<String> path, Map<String, String> query})? decodedLinkParts(Uri uri) {
  try {
    return (path: uri.pathSegments, query: uri.queryParameters);
  } on FormatException catch (e) {
    quantusPrint('Ignoring link with malformed percent-encoding: $e');
    return null;
  }
}

class PaymentIntent {
  final String to;
  final String amount;
  final String? ref;

  const PaymentIntent({required this.to, required this.amount, this.ref});

  static PaymentIntent? tryParseUrl(String input) {
    if (input.length > maxDeepLinkLength) return null;
    final uri = Uri.tryParse(input);
    if (uri == null) return null;
    final parts = decodedLinkParts(uri);
    if (parts == null || parts.path.isEmpty || parts.path.first != 'pay') return null;
    final to = parts.query['to'];
    final amount = parts.query['amount'];
    final ref = parts.query['ref'];
    if (to == null || to.isEmpty || to.length > maxAddressLength) return null;
    if (amount == null || !NumberFormattingService.wireAmountPattern.hasMatch(amount)) return null;
    if (ref != null && ref.length > maxPaymentRefLength) return null;
    return PaymentIntent(to: to, amount: amount, ref: ref);
  }
}

final paymentIntentProvider = StateProvider<PaymentIntent?>((_) => null);
