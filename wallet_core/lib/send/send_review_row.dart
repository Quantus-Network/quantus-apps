import 'package:flutter/foundation.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

/// One line of a send's review: a [label] and what stands beside it. A send's
/// strategy says what the lines hold; each app draws them its own way.
@immutable
sealed class SendReviewRow {
  const SendReviewRow(this.label);

  final String label;
}

/// A figure or other short text.
class SendReviewText extends SendReviewRow {
  const SendReviewText(super.label, this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is SendReviewText && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => 'SendReviewText($label, $value)';
}

/// An account's [address], to be shown with its checkphrase.
class SendReviewAddress extends SendReviewRow {
  const SendReviewAddress(super.label, this.address);

  final String address;

  @override
  bool operator ==(Object other) => other is SendReviewAddress && other.label == label && other.address == address;

  @override
  int get hashCode => Object.hash(label, address);

  @override
  String toString() => 'SendReviewAddress($label, $address)';
}

/// When a multisig proposal expires: its block, and the estimated time once
/// the chain's current block is known.
class SendReviewExpiry extends SendReviewRow {
  const SendReviewExpiry(super.label, this.expiry);

  final MultisigExpiryParts expiry;

  @override
  bool operator ==(Object other) => other is SendReviewExpiry && other.label == label && other.expiry == expiry;

  @override
  int get hashCode => Object.hash(label, expiry);

  @override
  String toString() => 'SendReviewExpiry($label, $expiry)';
}
