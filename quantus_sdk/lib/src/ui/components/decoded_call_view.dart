import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Density for [DecodedCallView] until design picks one layout.
enum DecodedCallLayout {
  /// Signing review: label above value, wrap, no ellipsis.
  stacked,

  /// Sheet/list: label left, value right, tighter.
  compact,
}

/// True when [summary] already puts this exact field on screen, so listing it
/// again would only add noise. Matches by identity, never by label or value.
bool coveredBySummary(CallField field, TransferSummary summary) {
  if (identical(field, summary.amountField)) return true;
  return summary.recipient != null && identical(field, summary.recipientField);
}

/// The transfer a call performs, or null when it dispatches another call.
///
/// A wrapper inherits the summary of the call it carries; the amount belongs
/// on that inner call, where the nested box shows it, not on the wrapper.
TransferSummary? heroSummary(DecodedCall call) => call.isWrapper ? null : call.summary;

/// Asset amounts stay in the payload's own raw units: decimals are per-asset
/// chain state an air-gapped signer cannot resolve.
String assetAmountText(BigInt amount, int assetId) => '$amount raw units of asset $assetId';

String? _resolvedPhrase(String address, String? Function(String address)? checkphraseOf) {
  final phrase = checkphraseOf?.call(address);
  if (phrase == null || phrase.isEmpty) return null;
  return phrase;
}

bool _isMonospace(ValueKind kind) => switch (kind) {
  ValueKind.address || ValueKind.hash || ValueKind.bytes => true,
  _ => false,
};

Widget _callDetailRow({
  required String label,
  required String value,
  required ValueKind kind,
  required DecodedCallLayout layout,
  String? note,
  String? checkphrase,
}) {
  final monospace = _isMonospace(kind);
  if (layout == DecodedCallLayout.stacked) {
    return DetailSummaryRow.stacked(
      label: label,
      value: value,
      monospace: monospace,
      note: note,
      checkphrase: checkphrase,
    );
  }
  return DetailSummaryRow(label: label, value: value, monospace: monospace, note: note, checkphrase: checkphrase);
}

/// Renders every parameter of a [DecodedCall], nested calls included.
///
/// Presentational only. Amounts and checkphrases are already-resolved strings
/// from the host app. Compact lists every field under the runtime title.
/// Stacked is the signing reading order: action title, hero amount and
/// recipient, then every remaining parameter.
class DecodedCallView extends StatelessWidget {
  final DecodedCall call;

  /// Nesting depth; nested calls indent and drop a level of visual weight.
  final int depth;

  /// Formats a native token amount for the current locale and currency display.
  final String Function(BigInt token) amountText;

  final DecodedCallLayout layout;

  /// Resolved checkphrase for an ss58 address, or null while loading / unknown.
  final String? Function(String address)? checkphraseOf;

  /// Host-provided signer row. Stacked wrappers insert it after nested calls.
  final Widget? signer;

  /// When false, the call title is omitted (the host already showed it).
  final bool showTitle;

  /// Label for the stacked recipient row. Ignored in compact layout.
  final String recipientLabel;

  const DecodedCallView({
    super.key,
    required this.call,
    required this.amountText,
    this.layout = DecodedCallLayout.compact,
    this.checkphraseOf,
    this.depth = 0,
    this.signer,
    this.showTitle = true,
    this.recipientLabel = 'To',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final stacked = layout == DecodedCallLayout.stacked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            stacked ? call.actionTitle : call.displayTitle,
            style: text.headingRow.copyWith(color: depth == 0 ? colors.textContent : colors.textMuted),
          ),
          SizedBox(height: stacked ? 8 : 4),
        ],
        ..._children(),
      ],
    );
  }

  List<Widget> _children() {
    if (layout == DecodedCallLayout.stacked && depth == 0 && signer != null && call.isWrapper) {
      return [
        for (final field in call.fields.whereType<NestedCallField>()) _field(field),
        signer!,
        for (final field in call.fields.where((f) => f is! NestedCallField)) _field(field),
      ];
    }
    return [..._body(), if (depth == 0 && signer != null) signer!];
  }

  List<Widget> _body() {
    if (layout != DecodedCallLayout.stacked) {
      return [for (final field in call.fields) _field(field)];
    }

    final summary = heroSummary(call);
    final recipient = summary?.recipient;
    return [
      if (summary != null) _TransferAmount(summary: summary, large: depth == 0, amountText: amountText),
      if (recipient != null)
        _callDetailRow(
          label: recipientLabel,
          value: recipient,
          kind: ValueKind.address,
          checkphrase: _resolvedPhrase(recipient, checkphraseOf),
          layout: layout,
        ),
      for (final field in call.fields)
        if (summary == null || !coveredBySummary(field, summary)) _field(field),
    ];
  }

  Widget _field(CallField field) => _CallFieldView(
    field: field,
    depth: depth,
    layout: layout,
    amountText: amountText,
    checkphraseOf: checkphraseOf,
    recipientLabel: recipientLabel,
  );
}

class _TransferAmount extends StatelessWidget {
  final TransferSummary summary;
  final bool large;
  final String Function(BigInt token) amountText;

  const _TransferAmount({required this.summary, required this.large, required this.amountText});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    if (summary.assetId != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          assetAmountText(summary.amount, summary.assetId!),
          style: text.headingRow.copyWith(color: colors.textContent),
        ),
      );
    }

    final style = large ? text.amountHero : text.amountInline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(amountText(summary.amount), style: style.copyWith(color: colors.textContent)),
      ),
    );
  }
}

class _CallFieldView extends StatelessWidget {
  final CallField field;
  final int depth;
  final DecodedCallLayout layout;
  final String Function(BigInt token) amountText;
  final String? Function(String address)? checkphraseOf;
  final String recipientLabel;

  const _CallFieldView({
    required this.field,
    required this.depth,
    required this.layout,
    required this.amountText,
    required this.checkphraseOf,
    required this.recipientLabel,
  });

  @override
  Widget build(BuildContext context) {
    return switch (field) {
      ValueField(:final label, :final value, :final kind, :final note) => _callDetailRow(
        label: label,
        value: value,
        kind: kind,
        note: note,
        checkphrase: kind == ValueKind.address ? _resolvedPhrase(value, checkphraseOf) : null,
        layout: layout,
      ),
      AmountField(:final label, :final token, :final assetId, :final note) => _callDetailRow(
        label: label,
        value: assetId == null ? amountText(token) : assetAmountText(token, assetId),
        kind: ValueKind.number,
        note: _amountNote(note, assetId),
        layout: layout,
      ),
      FieldGroup(:final label, :final items) => _FieldGroupView(
        label: label,
        items: items,
        depth: depth,
        layout: layout,
        amountText: amountText,
        checkphraseOf: checkphraseOf,
        recipientLabel: recipientLabel,
      ),
      NestedCallField(:final label, :final call, :final note) => _NestedCallBox(
        label: label,
        call: call,
        note: note,
        depth: depth,
        layout: layout,
        amountText: amountText,
        checkphraseOf: checkphraseOf,
        recipientLabel: recipientLabel,
      ),
    };
  }

  String? _amountNote(String? note, int? assetId) {
    if (assetId == null) return note;
    return [
      note,
      'Asset decimals are not part of this payload, so the raw amount is shown.',
    ].whereType<String>().join(' ');
  }
}

class _FieldGroupView extends StatelessWidget {
  final String label;
  final List<CallField> items;
  final int depth;
  final DecodedCallLayout layout;
  final String Function(BigInt token) amountText;
  final String? Function(String address)? checkphraseOf;
  final String recipientLabel;

  const _FieldGroupView({
    required this.label,
    required this.items,
    required this.depth,
    required this.layout,
    required this.amountText,
    required this.checkphraseOf,
    required this.recipientLabel,
  });

  @override
  Widget build(BuildContext context) {
    final stacked = layout == DecodedCallLayout.stacked;
    return Padding(
      padding: EdgeInsets.only(top: stacked ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(stacked ? label.toUpperCase() : label, style: _labelStyle(context)),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  _CallFieldView(
                    field: item,
                    depth: depth,
                    layout: layout,
                    amountText: amountText,
                    checkphraseOf: checkphraseOf,
                    recipientLabel: recipientLabel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NestedCallBox extends StatelessWidget {
  final String label;
  final DecodedCall call;
  final String? note;
  final int depth;
  final DecodedCallLayout layout;
  final String Function(BigInt token) amountText;
  final String? Function(String address)? checkphraseOf;
  final String recipientLabel;

  const _NestedCallBox({
    required this.label,
    required this.call,
    required this.note,
    required this.depth,
    required this.layout,
    required this.amountText,
    required this.checkphraseOf,
    required this.recipientLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final stacked = layout == DecodedCallLayout.stacked;
    return Padding(
      padding: EdgeInsets.only(top: stacked ? 14 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(stacked ? label.toUpperCase() : label, style: _labelStyle(context)),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: stacked ? 8 : 10),
            decoration: BoxDecoration(
              color: colors.bgSurface2,
              borderRadius: context.radiusV3.mdBorder,
              border: Border.all(color: colors.borderHairline),
            ),
            child: DecodedCallView(
              call: call,
              depth: depth + 1,
              layout: layout,
              amountText: amountText,
              checkphraseOf: checkphraseOf,
              recipientLabel: recipientLabel,
            ),
          ),
          if (note != null) ...[const SizedBox(height: 4), Text(note!, style: _noteStyle(context))],
        ],
      ),
    );
  }
}

TextStyle _labelStyle(BuildContext context) {
  return context.themeTextV3.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: context.colorsV3.textMuted);
}

TextStyle _noteStyle(BuildContext context) {
  return context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted);
}

/// The one-line-plus-subtitle form of a decoded call, for list rows and sheets.
///
/// A transfer keeps reading as an amount and a recipient; anything else names
/// the call rather than pretending to be a zero-value transfer.
class DecodedCallHeadline {
  /// Primary line: formatted amount for transfers, otherwise the call name.
  final String primary;

  /// Shortened recipient address when this call moves value, else null.
  final String? recipient;

  /// Subtitle for calls that move no value (the owning pallet), else null.
  final String? palletSubtitle;

  const DecodedCallHeadline({required this.primary, this.recipient, this.palletSubtitle});

  /// Either the recipient or the pallet, whichever this call has.
  String? get secondary => recipient ?? palletSubtitle;

  /// [amountText] formats a native token amount for the current locale and
  /// currency display; injected so this stays independent of Riverpod.
  static DecodedCallHeadline of(DecodedCall call, {required String Function(BigInt token) amountText}) {
    final summary = call.summary;
    if (summary == null) {
      return DecodedCallHeadline(
        primary: call.call.isEmpty ? call.pallet : call.humanCall,
        palletSubtitle: call.call.isEmpty ? null : call.pallet,
      );
    }
    return DecodedCallHeadline(
      primary: summary.assetId == null ? amountText(summary.amount) : '${summary.amount} (asset ${summary.assetId})',
      recipient: summary.recipient == null ? null : AddressFormattingService.formatAddress(summary.recipient!),
    );
  }
}
