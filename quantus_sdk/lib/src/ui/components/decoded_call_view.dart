import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Density for [DecodedCallView] until design picks one layout.
enum DecodedCallLayout {
  /// Signing review: label above value, wrap, no ellipsis.
  stacked,

  /// Sheet/list: label left, value right, tighter.
  compact,
}

/// Renders every parameter of a [DecodedCall], nested calls included.
///
/// Presentational only. Amounts and checkphrases are already-resolved strings
/// from the host app. Both layouts use v3 tokens; only geometry differs.
class DecodedCallView extends StatelessWidget {
  final DecodedCall call;

  /// Nesting depth; nested calls indent and drop a level of visual weight.
  final int depth;

  /// Formats a native token amount for the current locale and currency display.
  final String Function(BigInt token) amountText;

  final DecodedCallLayout layout;

  /// Resolved checkphrase for an ss58 address, or null while loading / unknown.
  final String? Function(String address)? checkphraseOf;

  const DecodedCallView({
    super.key,
    required this.call,
    required this.amountText,
    this.layout = DecodedCallLayout.compact,
    this.checkphraseOf,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          call.displayTitle,
          style: text.headingRow.copyWith(color: depth == 0 ? colors.textContent : colors.textMuted),
        ),
        SizedBox(height: layout == DecodedCallLayout.stacked ? 8 : 4),
        for (final field in call.fields)
          _CallFieldView(
            field: field,
            depth: depth,
            layout: layout,
            amountText: amountText,
            checkphraseOf: checkphraseOf,
          ),
      ],
    );
  }
}

class _CallFieldView extends StatelessWidget {
  final CallField field;
  final int depth;
  final DecodedCallLayout layout;
  final String Function(BigInt token) amountText;
  final String? Function(String address)? checkphraseOf;

  const _CallFieldView({
    required this.field,
    required this.depth,
    required this.layout,
    required this.amountText,
    required this.checkphraseOf,
  });

  @override
  Widget build(BuildContext context) {
    return switch (field) {
      ValueField(:final label, :final value, :final kind, :final note) => _FieldRow(
        label: label,
        value: value,
        kind: kind,
        note: note,
        checkphrase: kind == ValueKind.address ? _phrase(value) : null,
        layout: layout,
      ),
      AmountField(:final label, :final token, :final assetId, :final note) => _FieldRow(
        label: label,
        value: assetId == null ? amountText(token) : '$token raw units of asset #$assetId',
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
      ),
      NestedCallField(:final label, :final call, :final note) => _NestedCallBox(
        label: label,
        call: call,
        note: note,
        depth: depth,
        layout: layout,
        amountText: amountText,
        checkphraseOf: checkphraseOf,
      ),
    };
  }

  String? _phrase(String address) {
    final phrase = checkphraseOf?.call(address);
    if (phrase == null || phrase.isEmpty) return null;
    return phrase;
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

  const _FieldGroupView({
    required this.label,
    required this.items,
    required this.depth,
    required this.layout,
    required this.amountText,
    required this.checkphraseOf,
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

  const _NestedCallBox({
    required this.label,
    required this.call,
    required this.note,
    required this.depth,
    required this.layout,
    required this.amountText,
    required this.checkphraseOf,
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
            ),
          ),
          if (note != null) ...[const SizedBox(height: 4), Text(note!, style: _noteStyle(context))],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueKind kind;
  final String? note;
  final String? checkphrase;
  final DecodedCallLayout layout;

  const _FieldRow({
    required this.label,
    required this.value,
    required this.kind,
    required this.layout,
    this.note,
    this.checkphrase,
  });

  @override
  Widget build(BuildContext context) {
    return layout == DecodedCallLayout.stacked ? _stacked(context) : _compact(context);
  }

  Widget _stacked(BuildContext context) {
    final colors = context.colorsV3;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label.toUpperCase(), style: _labelStyle(context)),
          const SizedBox(height: 8),
          Text(value, style: _valueStyle(context, kind, layout)),
          if (note != null) ...[const SizedBox(height: 4), Text(note!, style: _noteStyle(context))],
          if (checkphrase != null) ...[
            const SizedBox(height: 12),
            Text('$label checkphrase'.toUpperCase(), style: _labelStyle(context)),
            const SizedBox(height: 8),
            Text(checkphrase!, style: _valueStyle(context, kind, layout).copyWith(color: colors.semanticLilac)),
          ],
        ],
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final colors = context.colorsV3;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: Text(label, style: _labelStyle(context))),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value, style: _valueStyle(context, kind, layout), textAlign: TextAlign.right, softWrap: true),
                    if (checkphrase != null)
                      Text(
                        checkphrase!,
                        style: context.themeTextV3.caption.copyWith(color: colors.semanticLilac),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ),
            ],
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

TextStyle _valueStyle(BuildContext context, ValueKind kind, DecodedCallLayout layout) {
  final text = context.themeTextV3;
  final colors = context.colorsV3;
  final stacked = layout == DecodedCallLayout.stacked;
  final base = switch (kind) {
    ValueKind.address || ValueKind.hash || ValueKind.bytes => stacked ? text.dataAddressLarge : text.dataAddress,
    _ => text.body,
  };
  return base.copyWith(color: colors.textContent);
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
      primary: summary.assetId == null ? amountText(summary.amount) : '${summary.amount} (asset #${summary.assetId})',
      recipient: summary.recipient == null ? null : AddressFormattingService.formatAddress(summary.recipient!),
    );
  }
}
