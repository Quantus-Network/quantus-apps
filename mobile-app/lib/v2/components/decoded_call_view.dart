import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

/// Renders every parameter of a decoded multisig proposal, nested calls included.
class DecodedCallView extends ConsumerWidget {
  final DecodedCall call;
  final int depth;

  const DecodedCallView({super.key, required this.call, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          call.displayTitle,
          style: text.labelData.copyWith(color: depth == 0 ? colors.textContent : colors.textMuted),
        ),
        const SizedBox(height: 4),
        for (final field in call.fields) _field(context, ref, field),
      ],
    );
  }

  Widget _field(BuildContext context, WidgetRef ref, CallField field) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final valueStyle = text.dataAddress.copyWith(color: colors.textContent);

    return switch (field) {
      ValueField(:final label, :final value, :final note) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailSummaryRow.review(label: label, value: value, valueStyle: valueStyle),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(note, style: text.caption.copyWith(color: colors.textMuted2)),
              ),
          ],
        ),
      ),
      AmountField(:final label, :final token, :final assetId, :final note) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailSummaryRow.review(
              label: label,
              value: assetId == null
                  ? ref.watch(txAmountDisplayProvider)(token, isSend: true).primaryAmount
                  : '$token (asset #$assetId, raw units)',
              valueStyle: valueStyle,
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(note, style: text.caption.copyWith(color: colors.textMuted2)),
              ),
          ],
        ),
      ),
      FieldGroup(:final label, :final items) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: text.labelMonogram.copyWith(color: colors.textMuted2)),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final item in items) _field(context, ref, item)],
              ),
            ),
          ],
        ),
      ),
      NestedCallField(:final label, :final call, :final note) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: text.labelMonogram.copyWith(color: colors.textMuted2)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.bgSurface2,
                borderRadius: context.radiusV3.mdBorder,
                border: Border.all(color: colors.borderHairline),
              ),
              child: DecodedCallView(call: call, depth: depth + 1),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(note, style: text.caption.copyWith(color: colors.textMuted2)),
              ),
          ],
        ),
      ),
    };
  }
}

/// The one-line-plus-subtitle form used by multisig proposal rows and sheets.
class DecodedCallHeadline {
  final String primary;
  final String? recipient;
  final String? palletSubtitle;

  const DecodedCallHeadline({required this.primary, this.recipient, this.palletSubtitle});

  String? get secondary => recipient ?? palletSubtitle;

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
