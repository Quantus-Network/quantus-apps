/// Display model for a decoded runtime call.
///
/// Deliberately UI-agnostic and free of locale/formatting concerns: amounts stay
/// as smallest-unit [BigInt]s and addresses as ss58 strings, so the same tree can be
/// rendered by the hot wallet's proposal sheets and by the air-gapped cold
/// wallet's signing screen.
///
/// The contract that matters for signing: a [DecodedCall] carries **every** field
/// of the call it describes. Nothing is summarised away — [DecodedCall.summary]
/// is an *additional* hint for the hero position, never a replacement for
/// [DecodedCall.fields].
library;

/// How a [ValueField] should be presented (monospace, checkphrase, truncation).
enum ValueKind {
  /// ss58 account address; renderers should offer a checkphrase.
  address,

  /// 32-byte hash as `0x…` hex.
  hash,

  /// Opaque byte blob as `0x…` hex.
  bytes,

  /// Integer-ish scalar (ids, indices, counts).
  number,

  boolean,

  /// A block number, or a wall-clock duration/instant.
  blockOrTime,

  text,
}

sealed class CallField {
  /// Human label, e.g. `Destination`.
  final String label;

  const CallField(this.label);
}

/// A single scalar parameter rendered as text.
class ValueField extends CallField {
  final String value;
  final ValueKind kind;

  /// Caveat shown alongside the value, e.g. that a referenced preimage's
  /// contents are not part of this payload.
  final String? note;

  const ValueField(super.label, this.value, {this.kind = ValueKind.text, this.note});
}

/// A balance parameter. Kept as a smallest-unit [BigInt] so the renderer owns formatting.
class AmountField extends CallField {
  final BigInt token;

  /// Asset id for non-native balances; null means the native token.
  final int? assetId;

  final String? note;

  const AmountField(super.label, this.token, {this.assetId, this.note});
}

/// A call nested inside this one: a multisig proposal's inner call, a batch
/// item, `as_derivative`, an inline referendum proposal.
class NestedCallField extends CallField {
  final DecodedCall call;
  final String? note;

  const NestedCallField(super.label, this.call, {this.note});
}

/// A composite parameter: a `Vec<_>`, a struct, or a tuple list.
class FieldGroup extends CallField {
  final List<CallField> items;

  const FieldGroup(super.label, this.items);
}

/// The value transfer a call performs, when it performs one.
///
/// Propagated up from a nested call, so a multisig `propose`/`approve` wrapping
/// a transfer still surfaces the amount for the hero position.
class TransferSummary {
  final BigInt amount;

  /// ss58 recipient, or null when the destination is not a plain account id.
  final String? recipient;

  /// Asset id for non-native transfers; null means the native token.
  final int? assetId;

  /// True for a scheduled, reversible transfer — a materially different action
  /// from an immediate send, so the headline names it.
  final bool reversible;

  /// The exact fields this summary restates, so a renderer that leads with the
  /// summary can suppress those fields and no others — a different field that
  /// merely carries an equal value is still listed.
  final CallField? amountField;
  final CallField? recipientField;

  const TransferSummary({
    required this.amount,
    this.recipient,
    this.assetId,
    this.reversible = false,
    this.amountField,
    this.recipientField,
  });
}

/// A fully decoded runtime call: pallet, call name, every parameter, plus an
/// optional transfer hint.
class DecodedCall {
  /// Runtime pallet name as the metadata declares it, e.g. `Multisig`.
  final String pallet;

  /// Call name in the runtime's own snake_case, e.g. `transfer_allow_death`.
  /// Kept verbatim so what is displayed can be matched against the runtime.
  final String call;

  final List<CallField> fields;

  final TransferSummary? summary;

  const DecodedCall({required this.pallet, required this.call, required this.fields, this.summary});

  /// `Multisig · approve` — pallet and call exactly as the runtime names them.
  String get displayTitle => '$pallet · $call';

  /// `Multisig · approve → Balances · transfer_allow_death` — the exact runtime
  /// identity of every call in the payload, in dispatch order, nested calls
  /// included. The one line that never summarises; the signing screen renders
  /// it in the Advanced list, and only there.
  String get displayTitleChain => [for (final c in _withNested) c.displayTitle].join(' → ');

  Iterable<DecodedCall> get _withNested sync* {
    yield this;
    for (final nested in _nestedCalls(fields)) {
      yield* nested._withNested;
    }
  }

  /// True when this call dispatches another call it carries — a multisig
  /// approval or proposal, a batch, an inline governance proposal — wherever
  /// that nested call sits, including inside a parameter group.
  bool get isWrapper => _nestedCalls(fields).isNotEmpty;

  static Iterable<DecodedCall> _nestedCalls(List<CallField> fields) sync* {
    for (final field in fields) {
      if (field is NestedCallField) yield field.call;
      if (field is FieldGroup) yield* _nestedCalls(field.items);
    }
  }

  /// `SEND`, `REVERSIBLE SEND`, `ASSET SEND`, `MULTISIG APPROVE` — the action
  /// in the words a signer thinks in, for the headline position.
  ///
  /// INTENTIONALLY opinionated, do not "fix" this back to runtime naming:
  /// every runtime spelling of "move value" — `transfer_allow_death`,
  /// `transfer_keep_alive`, `force_transfer`, `Assets · transfer` — collapses
  /// into the one distinction a human actually weighs (send / reversible send /
  /// asset send), because runtime naming is noise to the person deciding
  /// whether to sign. The exact `pallet · call` identity is not lost: it lives
  /// in exactly one place, [displayTitleChain], on the Advanced list.
  ///
  /// Only a call that moves value *itself* reads as a send: a wrapper carries
  /// the summary of the call it dispatches, and naming that wrapper SEND would
  /// hide the approval or batch the signer is actually authorising.
  String get actionTitle {
    final transfer = summary;
    if (transfer != null && !isWrapper) {
      final kind = transfer.assetId != null ? 'ASSET SEND' : 'SEND';
      return transfer.reversible ? 'REVERSIBLE $kind' : kind;
    }
    return '$pallet $humanCall'.trim().toUpperCase();
  }

  /// `Transfer allow death` — the call name made readable, for headings.
  String get humanCall {
    if (call.isEmpty) return call;
    final words = call.split('_').where((w) => w.isNotEmpty).join(' ');
    return words[0].toUpperCase() + words.substring(1);
  }
}
