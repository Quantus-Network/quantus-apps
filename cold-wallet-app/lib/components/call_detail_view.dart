import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/detail_row.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// True when [summary] already puts this exact field on screen, so listing it
/// again would only add noise. Matches by identity, never by label or value, so
/// a renamed field — or a different field that merely carries an equal value —
/// can never be silently dropped.
bool coveredBySummary(CallField field, TransferSummary summary) {
  if (identical(field, summary.amountField)) return true;
  // With no plain recipient there is no To row, so the field must be listed.
  return summary.recipient != null && identical(field, summary.recipientField);
}

/// The transfer a call performs, or null when it dispatches another call.
///
/// A wrapper (multisig approve, batch, `as_derivative`) inherits the summary of
/// the call it carries; the amount belongs on that inner call, where the nested
/// box shows it, not on the wrapper.
TransferSummary? heroSummary(DecodedCall call) => call.isWrapper ? null : call.summary;

/// The amount, recipient, and every parameter the two of them do not already
/// cover — the body shared by the top-level review and each nested call box.
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

/// The amount being moved, in the largest type on the screen.
class TransferAmount extends StatelessWidget {
  final TransferSummary summary;

  /// Top-level calls get the hero treatment; nested ones step down a size.
  final bool large;

  const TransferAmount({super.key, required this.summary, this.large = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    if (summary.assetId != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          '${summary.amount} raw units of asset #${summary.assetId}',
          style: text.mediumTitle?.copyWith(color: colors.textPrimary),
        ),
      );
    }

    final amount = NumberFormattingService().formatAmount(summary.amount);
    final style = large ? text.transactionDetailAmountPrimary : text.conversionAmountPrimary;
    final symbolStyle = large ? text.transactionDetailAmountSymbol : text.conversionAmountPrimary;

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
                style: style?.copyWith(color: colors.textPrimary),
              ),
              TextSpan(
                text: ' ${AppConstants.tokenSymbol}',
                style: symbolStyle?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A decoded call rendered the way a signer reads it: what it does, how much,
/// to whom — then every remaining parameter, nested calls included.
///
/// The summary is a lead, never a replacement: any field it does not already
/// show is listed underneath, so if a byte is being signed it is on this screen.
class CallDetailView extends StatelessWidget {
  final DecodedCall call;

  /// Nesting depth; nested calls are boxed and indented.
  final int depth;

  const CallDetailView({super.key, required this.call, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          call.actionTitle,
          style: text.smallTitle?.copyWith(color: depth == 0 ? colors.textPrimary : colors.checksum),
        ),
        Text(call.displayTitle, style: text.detail?.copyWith(color: colors.textMuted)),
        ...callSummaryBody(call, depth: depth),
      ],
    );
  }
}

class CallFieldView extends ConsumerWidget {
  final CallField field;
  final int depth;

  const CallFieldView({super.key, required this.field, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;

    switch (field) {
      case ValueField(:final label, :final value, :final kind, :final note):
        if (kind == ValueKind.address) {
          return AddressWithCheckphrase(label: label, address: value, note: note);
        }
        return DetailRow(
          label: label,
          value: value,
          monospace: kind == ValueKind.hash || kind == ValueKind.bytes,
          note: note,
        );

      case AmountField(:final label, :final token, :final assetId, :final note):
        return DetailRow(
          label: label,
          value: assetId == null
              ? '${NumberFormattingService().formatAmount(token)} ${AppConstants.tokenSymbol}'
              : '$token raw units of asset #$assetId',
          note: assetId == null
              ? note
              : [
                  note,
                  'Asset decimals are not part of this payload, so the raw amount is shown.',
                ].whereType<String>().join(' '),
        );

      case FieldGroup(:final label, :final items):
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label.toUpperCase(), style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final item in items) CallFieldView(field: item, depth: depth)],
                ),
              ),
            ],
          ),
        );

      case NestedCallField(:final label, :final call, :final note):
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label.toUpperCase(), style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderButton),
                ),
                child: CallDetailView(call: call, depth: depth + 1),
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note, style: text.detail?.copyWith(color: colors.textMuted)),
              ],
            ],
          ),
        );
    }
  }
}
