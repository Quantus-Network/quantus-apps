import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

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

  /// Caveat shown under the value, e.g. that a hash-referenced proposal's
  /// contents are not part of the payload.
  final String? note;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
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
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: text.detail?.copyWith(color: colors.textMuted)),
          ],
        ],
      ),
    );
  }
}
