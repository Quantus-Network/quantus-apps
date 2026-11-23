import 'package:flutter/foundation.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

/// What a line of a send's review tells. An app that shows some of these its
/// own way, in a headline say, finds them by it.
enum SendReviewRowKind {
  /// Who is paid.
  recipient,

  /// How much.
  amount,

  /// What the network takes.
  fee,

  /// What is paid in all.
  total,

  /// The account of this wallet that signs the send and pays what it costs,
  /// where that is not the account the funds leave: a multisig's member.
  signer,

  /// An amount held while the send is open, and returned.
  deposit,

  /// What this kind of send charges beyond the network's fee.
  charge,

  /// Anything else this kind of send has to tell.
  detail,
}

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

/// How many of a multisig's [signers] must approve a proposal: its
/// [threshold].
class SendReviewThreshold extends SendReviewRow {
  const SendReviewThreshold(super.label, {required this.threshold, required this.signers, super.kind});

  final int threshold;
  final int signers;

  /// The two as a fraction, "2/3".
  String get text => '$threshold/$signers';

  @override
  bool operator ==(Object other) =>
      other is SendReviewThreshold &&
      other.label == label &&
      other.threshold == threshold &&
      other.signers == signers &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(label, threshold, signers, kind);

  @override
  String toString() => 'SendReviewThreshold($label, $text, ${kind.name})';
}
