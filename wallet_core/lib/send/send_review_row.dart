import 'package:flutter/foundation.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

/// What a line of a send's review tells: who is paid, how much, what the
/// network takes, what leaves the account in all, or a detail of this kind
/// of send. An app that shows some of these its own way, in a headline say,
/// finds them by it.
enum SendReviewRowKind { recipient, amount, fee, total, detail }

/// One line of a send's review: a [label] and what stands beside it. A send's
/// strategy says what the lines hold; each app draws them its own way.
@immutable
sealed class SendReviewRow {
  const SendReviewRow(this.label, {this.kind = SendReviewRowKind.detail});

  final String label;
  final SendReviewRowKind kind;
}

/// A figure or other short text.
class SendReviewText extends SendReviewRow {
  const SendReviewText(super.label, this.value, {super.kind});

  final String value;

  @override
  bool operator ==(Object other) =>
      other is SendReviewText && other.label == label && other.value == value && other.kind == kind;

  @override
  int get hashCode => Object.hash(label, value, kind);

  @override
  String toString() => 'SendReviewText($label, $value, ${kind.name})';
}

/// An account's [address], to be shown with its checkphrase.
class SendReviewAddress extends SendReviewRow {
  const SendReviewAddress(super.label, this.address, {super.kind});

  final String address;

  @override
  bool operator ==(Object other) =>
      other is SendReviewAddress && other.label == label && other.address == address && other.kind == kind;

  @override
  int get hashCode => Object.hash(label, address, kind);

  @override
  String toString() => 'SendReviewAddress($label, $address, ${kind.name})';
}

/// When a multisig proposal expires: its block, and the estimated time once
/// the chain's current block is known.
class SendReviewExpiry extends SendReviewRow {
  const SendReviewExpiry(super.label, this.expiry, {super.kind});

  final MultisigExpiryParts expiry;

  @override
  bool operator ==(Object other) =>
      other is SendReviewExpiry && other.label == label && other.expiry == expiry && other.kind == kind;

  @override
  int get hashCode => Object.hash(label, expiry, kind);

  @override
  String toString() => 'SendReviewExpiry($label, $expiry, ${kind.name})';
}
