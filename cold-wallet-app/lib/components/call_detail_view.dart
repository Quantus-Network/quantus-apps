import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide CallFieldView;
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';

/// True when [summary] already puts this exact field on screen, so listing it
/// again would only add noise. Matches by identity, never by label or value.
bool coveredBySummary(CallField field, TransferSummary summary) {
  if (identical(field, summary.amountField)) return true;
  return summary.recipient != null && identical(field, summary.recipientField);
}

/// A wrapper inherits its inner summary, but the amount belongs on the nested
/// call it dispatches rather than on the wrapper.
TransferSummary? heroSummary(DecodedCall call) => call.isWrapper ? null : call.summary;

/// Asset decimals are chain state unavailable to an air-gapped signer.
String assetAmountText(BigInt amount, int assetId) => '$amount raw units of asset $assetId';

/// The amount, recipient, and every parameter those two do not already cover.
List<Widget> callSummaryBody(DecodedCall call, {int depth = 0}) {
  final summary = heroSummary(call);
  final recipient = summary?.recipient;

  return [
    if (summary != null) TransferAmount(summary: summary, large: depth == 0),
    if (recipient != null) AddressWithCheckphrase(label: 'To', address: recipient),
    for (final field in call.fields)
      if (summary == null || !coveredBySummary(field, summary)) CallFieldView(field: field, depth: depth),
  ];
}

class TransferAmount extends StatelessWidget {
  final TransferSummary summary;
  final bool large;

  const TransferAmount({super.key, required this.summary, this.large = true});

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

    final amount = NumberFormattingService().formatAmount(summary.amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: amount,
                style: (large ? text.amountHero : text.amountInline).copyWith(color: colors.textContent),
              ),
              TextSpan(
                text: ' ${AppConstants.tokenSymbol}',
                style: text.amountInline.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders every signed call parameter, including all nested calls. The summary
/// leads the display but never replaces fields it does not restate exactly.
class CallDetailView extends StatelessWidget {
  final DecodedCall call;
  final int depth;

  const CallDetailView({super.key, required this.call, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          call.actionTitle,
          style: text.headingRow.copyWith(color: depth == 0 ? colors.textContent : colors.semanticLilac),
        ),
        ...callSummaryBody(call, depth: depth),
      ],
    );
  }
}

class CallFieldView extends StatelessWidget {
  final CallField field;
  final int depth;

  const CallFieldView({super.key, required this.field, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return switch (field) {
      ValueField(:final label, :final value, :final kind, :final note) =>
        kind == ValueKind.address
            ? AddressWithCheckphrase(label: label, address: value, note: note)
            : DetailSummaryRow.stacked(
                label: label,
                value: value,
                monospace: kind == ValueKind.hash || kind == ValueKind.bytes,
                note: note,
              ),
      AmountField(:final label, :final token, :final assetId, :final note) => DetailSummaryRow.stacked(
        label: label,
        value: assetId == null
            ? '${NumberFormattingService().formatAmount(token)} ${AppConstants.tokenSymbol}'
            : assetAmountText(token, assetId),
        note: assetId == null
            ? note
            : [
                note,
                'Asset decimals are not part of this payload, so the raw amount is shown.',
              ].whereType<String>().join(' '),
      ),
      FieldGroup(:final label, :final items) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label.toUpperCase(), style: text.labelMonogram.copyWith(color: colors.textMuted)),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final item in items) CallFieldView(field: item, depth: depth)],
              ),
            ),
          ],
        ),
      ),
      NestedCallField(:final label, :final call, :final note) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label.toUpperCase(), style: text.labelMonogram.copyWith(color: colors.textMuted)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.bgSurface2,
                borderRadius: context.radiusV3.mdBorder,
                border: Border.all(color: colors.borderHairline),
              ),
              child: CallDetailView(call: call, depth: depth + 1),
            ),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(note, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ],
        ),
      ),
    };
  }
}
