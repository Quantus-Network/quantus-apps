import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/v2/components/detail_summary_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Renders every parameter of a [DecodedCall], nested calls included.
///
/// Multisig proposals are not always transfers — governance votes, runtime
/// upgrade authorisations and batches all arrive through the same pallet — so a
/// transfer-shaped layout silently misreports them. This shows the call the
/// runtime actually declared, with each of its parameters.
class DecodedCallView extends ConsumerWidget {
  final DecodedCall call;

  /// Nesting depth; nested calls indent and drop a level of visual weight.
  final int depth;

  const DecodedCallView({super.key, required this.call, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          call.displayTitle,
          style: text.detail?.copyWith(
            color: depth == 0 ? colors.textPrimary : colors.textSecondary,
            fontWeight: FontWeight.w600,
            fontFamily: AppTextTheme.fontFamilySecondary,
          ),
        ),
        const SizedBox(height: 4),
        for (final field in call.fields) _field(context, ref, field),
      ],
    );
  }

  Widget _field(BuildContext context, WidgetRef ref, CallField field) {
    final colors = context.colors;
    final text = context.themeText;

    switch (field) {
      case ValueField(:final label, :final value, :final note):
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailSummaryRow.review(label: label, value: value),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(note, style: text.detail?.copyWith(color: colors.textTertiary, fontSize: 11)),
                ),
            ],
          ),
        );

      case AmountField(:final label, :final token, :final assetId, :final note):
        final value = assetId == null
            ? ref.watch(txAmountDisplayProvider)(token, isSend: true).primaryAmount
            : '$token (asset #$assetId, raw units)';
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DetailSummaryRow.review(label: label, value: value),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(note, style: text.detail?.copyWith(color: colors.textTertiary, fontSize: 11)),
                ),
            ],
          ),
        );

      case FieldGroup(:final label, :final items):
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: text.transactionDetailRowLabel?.copyWith(color: colors.textTertiary)),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final item in items) _field(context, ref, item)],
                ),
              ),
            ],
          ),
        );

      case NestedCallField(:final label, :final call, :final note):
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: text.transactionDetailRowLabel?.copyWith(color: colors.textTertiary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderButton.useOpacity(0.4)),
                ),
                child: DecodedCallView(call: call, depth: depth + 1),
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(note, style: text.detail?.copyWith(color: colors.textTertiary, fontSize: 11)),
                ),
            ],
          ),
        );
    }
  }
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
