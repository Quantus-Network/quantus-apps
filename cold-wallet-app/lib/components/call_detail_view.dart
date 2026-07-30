import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/detail_row.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Resolves human checkphrases for every address on screen, not just a
/// destination — an approval or a governance call can name several accounts, and
/// each one needs to be verifiable by eye.
final _checkphraseProvider = FutureProvider.family<String, String>((ref, address) async {
  return (await HumanReadableChecksumService().getHumanReadableName(address)) ?? '';
});

/// Renders every parameter of a decoded call, recursing into nested calls.
///
/// This is the whole point of the signing screen: nothing is summarised away and
/// nothing is hidden behind a "details" tap. If a field is in the bytes being
/// signed, it is on this screen.
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
          call.displayTitle,
          style: text.transactionDetailRowValue?.copyWith(
            color: depth == 0 ? colors.textPrimary : colors.checksum,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final field in call.fields) _CallFieldView(field: field, depth: depth),
      ],
    );
  }
}

class _CallFieldView extends ConsumerWidget {
  final CallField field;
  final int depth;

  const _CallFieldView({required this.field, required this.depth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;

    switch (field) {
      case ValueField(:final label, :final value, :final kind, :final note):
        if (kind == ValueKind.address) {
          return _AddressField(label: label, address: value, note: note);
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
                  children: [for (final item in items) _CallFieldView(field: item, depth: depth)],
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

/// An address plus its checkphrase, so the signer can verify it out loud rather
/// than character by character.
class _AddressField extends ConsumerWidget {
  final String label;
  final String address;
  final String? note;

  const _AddressField({required this.label, required this.address, this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final checkphrase = ref.watch(_checkphraseProvider(address));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailRow(label: label, value: address, monospace: true, note: note),
        checkphrase.maybeWhen(
          data: (phrase) => phrase.isEmpty
              ? const SizedBox.shrink()
              : DetailRow(label: '$label checkphrase', value: phrase, valueColor: colors.checksum),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
