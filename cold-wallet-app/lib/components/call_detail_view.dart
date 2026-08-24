import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide CallFieldView;
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
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

String _formatAmount(AmountField field) {
  if (field.assetId == null) {
    return '${NumberFormattingService().formatAmount(field.token)} ${AppConstants.tokenSymbol}';
  }
  return assetAmountText(field.token, field.assetId!);
}

String? _amountNote(AmountField field) {
  if (field.assetId == null) return field.note;
  return [
    field.note,
    'Asset decimals are not part of this payload, so the raw amount is shown.',
  ].whereType<String>().join(' ');
}

Widget _address(ValueField field) => AddressWithCheckphrase(label: field.label, address: field.value, note: field.note);

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
    return sdk.CallFieldView(
      field: field,
      depth: depth,
      layout: DetailSummaryLayout.stacked,
      titleOf: (call) => call.actionTitle,
      formatAmount: _formatAmount,
      addressBuilder: _address,
      amountNoteOf: _amountNote,
      nestedCallBuilder: (call, nestedDepth) => CallDetailView(call: call, depth: nestedDepth),
    );
  }
}
