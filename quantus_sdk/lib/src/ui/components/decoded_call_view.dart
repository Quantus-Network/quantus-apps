import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

String? _fieldNote(AmountField field) => field.note;

/// Walks a [DecodedCall] tree; hosts supply [titleOf], [formatAmount] and optional builders.
class DecodedCallView extends StatelessWidget {
  final DecodedCall call;
  final int depth;
  final DetailSummaryLayout layout;
  final String Function(DecodedCall call) titleOf;
  final String Function(AmountField field) formatAmount;
  final Widget Function(ValueField field)? addressBuilder;
  final String? Function(AmountField field) amountNoteOf;
  final Widget Function(DecodedCall call, int depth)? nestedCallBuilder;

  const DecodedCallView({
    super.key,
    required this.call,
    required this.titleOf,
    required this.formatAmount,
    this.layout = DetailSummaryLayout.compact,
    this.addressBuilder,
    this.amountNoteOf = _fieldNote,
    this.nestedCallBuilder,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final titleStyle = layout == DetailSummaryLayout.stacked
        ? text.headingRow.copyWith(color: depth == 0 ? colors.textContent : colors.semanticLilac)
        : text.labelData.copyWith(color: depth == 0 ? colors.textContent : colors.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titleOf(call), style: titleStyle),
        if (layout == DetailSummaryLayout.compact) const SizedBox(height: 4),
        for (final field in call.fields)
          CallFieldView(
            field: field,
            depth: depth,
            layout: layout,
            titleOf: titleOf,
            formatAmount: formatAmount,
            addressBuilder: addressBuilder,
            amountNoteOf: amountNoteOf,
            nestedCallBuilder: nestedCallBuilder,
          ),
      ],
    );
  }
}

/// One [CallField], including groups and nested calls.
class CallFieldView extends StatelessWidget {
  final CallField field;
  final int depth;
  final DetailSummaryLayout layout;
  final String Function(DecodedCall call) titleOf;
  final String Function(AmountField field) formatAmount;
  final Widget Function(ValueField field)? addressBuilder;
  final String? Function(AmountField field) amountNoteOf;
  final Widget Function(DecodedCall call, int depth)? nestedCallBuilder;

  const CallFieldView({
    super.key,
    required this.field,
    required this.titleOf,
    required this.formatAmount,
    this.layout = DetailSummaryLayout.compact,
    this.addressBuilder,
    this.amountNoteOf = _fieldNote,
    this.nestedCallBuilder,
    this.depth = 0,
  });

  CallFieldView _child(CallField field) {
    return CallFieldView(
      field: field,
      depth: depth,
      layout: layout,
      titleOf: titleOf,
      formatAmount: formatAmount,
      addressBuilder: addressBuilder,
      amountNoteOf: amountNoteOf,
      nestedCallBuilder: nestedCallBuilder,
    );
  }

  Widget _nestedCall(DecodedCall call) {
    return nestedCallBuilder?.call(call, depth + 1) ??
        DecodedCallView(
          call: call,
          depth: depth + 1,
          layout: layout,
          titleOf: titleOf,
          formatAmount: formatAmount,
          addressBuilder: addressBuilder,
          amountNoteOf: amountNoteOf,
          nestedCallBuilder: nestedCallBuilder,
        );
  }

  @override
  Widget build(BuildContext context) {
    return switch (field) {
      final ValueField value => _value(context, value),
      final AmountField amount => _amount(context, amount),
      final FieldGroup group => _group(context, group),
      final NestedCallField nested => _nested(context, nested),
    };
  }

  Widget _value(BuildContext context, ValueField field) {
    if (field.kind == ValueKind.address && addressBuilder != null) {
      return addressBuilder!(field);
    }
    return _row(
      context,
      label: field.label,
      value: field.value,
      monospace: field.kind == ValueKind.hash || field.kind == ValueKind.bytes,
      note: field.note,
    );
  }

  Widget _amount(BuildContext context, AmountField field) {
    return _row(context, label: field.label, value: formatAmount(field), note: amountNoteOf(field));
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String value,
    bool monospace = false,
    String? note,
  }) {
    if (layout == DetailSummaryLayout.stacked) {
      return DetailSummaryRow.stacked(label: label, value: value, monospace: monospace, note: note);
    }
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return DetailSummaryRow(
      label: label,
      value: value,
      layout: DetailSummaryLayout.compact,
      padding: const EdgeInsets.only(top: 6),
      monospace: monospace,
      note: note,
      valueStyle: text.dataAddress.copyWith(color: colors.textContent),
    );
  }

  Widget _group(BuildContext context, FieldGroup field) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final stacked = layout == DetailSummaryLayout.stacked;
    return Padding(
      padding: EdgeInsets.only(top: stacked ? 10 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stacked ? field.label.toUpperCase() : field.label,
            style: text.labelMonogram.copyWith(color: stacked ? colors.textMuted : colors.textMuted2),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final item in field.items) _child(item)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nested(BuildContext context, NestedCallField field) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final stacked = layout == DetailSummaryLayout.stacked;
    return Padding(
      padding: EdgeInsets.only(top: stacked ? 14 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stacked ? field.label.toUpperCase() : field.label,
            style: text.labelMonogram.copyWith(color: stacked ? colors.textMuted : colors.textMuted2),
          ),
          SizedBox(height: stacked ? 8 : 4),
          Container(
            padding: stacked ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.bgSurface2,
              borderRadius: context.radiusV3.mdBorder,
              border: Border.all(color: colors.borderHairline),
            ),
            child: _nestedCall(field.call),
          ),
          if (field.note != null)
            Padding(
              padding: EdgeInsets.only(top: stacked ? 6 : 4),
              child: Text(field.note!, style: text.caption.copyWith(color: colors.textMuted)),
            ),
        ],
      ),
    );
  }
}
