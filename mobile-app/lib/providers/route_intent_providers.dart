import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
/// legitimate /pay link is ~190 chars (host + path, ~50-char SS58 address,
/// NNNNNNNNNNNNNNNNNNNN.NNNNNNNNNNNN amount, 64-char ref), so 256 for the
/// whole URL leaves headroom while keeping every parsed value bounded.
const int maxDeepLinkLength = 256;
const int maxAddressLength = 64;
const int maxPaymentRefLength = 64;

class PaymentIntent {
  final String to;
  final String amount;
  final String? ref;

  const PaymentIntent({required this.to, required this.amount, this.ref});

  /// Wire amount format for /pay links: NNN[.NNN] in QUAN, dot as the decimal
  /// separator, up to [AppConstants.decimals] fractional digits. Scientific
  /// notation, signs, and grouping separators are not part of the scheme —
  /// parsing those into a BigInt can block the UI isolate for minutes.
  static final RegExp _amountPattern = RegExp('^\\d{1,20}(\\.\\d{1,${AppConstants.decimals}})?\$');

  static PaymentIntent? tryParseUrl(String input) {
    if (input.length > maxDeepLinkLength) return null;
    final uri = Uri.tryParse(input);
    if (uri == null || uri.pathSegments.isEmpty || uri.pathSegments.first != 'pay') return null;
    final to = uri.queryParameters['to'];
    final amount = uri.queryParameters['amount'];
    final ref = uri.queryParameters['ref'];
    if (to == null || to.isEmpty || to.length > maxAddressLength) return null;
    if (amount == null || !_amountPattern.hasMatch(amount)) return null;
    if (ref != null && ref.length > maxPaymentRefLength) return null;
    return PaymentIntent(to: to, amount: amount, ref: ref);
  }
}

final paymentIntentProvider = StateProvider<PaymentIntent?>((_) => null);
