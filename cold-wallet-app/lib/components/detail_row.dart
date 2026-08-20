import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Label-above-value row used throughout the signing review screen.
///
/// Values wrap rather than ellipsize: a signer must be able to read a full
/// address or hash, so nothing on this screen is ever visually truncated.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;

  /// Monospace value, for addresses, hashes and byte blobs.
  final bool monospace;

  final Color? valueColor;

  /// A second reading of the same value, shown directly under it — the human
  /// checkphrase for an address.
  final String? subValue;

  final Color? subValueColor;

  /// Caveat shown under the value, e.g. that a hash-referenced proposal's
  /// contents are not part of the payload.
  final String? note;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
    this.subValue,
    this.subValueColor,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 6),
          Text(
            value,
            style: monospace
                ? text.transactionDetailRowValue?.copyWith(color: valueColor ?? colors.textPrimary)
                : text.smallParagraph?.copyWith(color: valueColor ?? colors.textPrimary),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 4),
            Text(subValue!, style: text.smallParagraph?.copyWith(color: subValueColor ?? colors.textSecondary)),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: text.detail?.copyWith(color: colors.textMuted)),
          ],
        ],
      ),
    );
  }
}
