import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Circular lock badge used for encrypted / private UI (always Quantus orange).
class EncryptedLockBadge extends StatelessWidget {
  final double size;

  const EncryptedLockBadge({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.bgSurface2,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: colors.borderHairline),
      ),
      child: QuantusIcon(QuantusIcons.lock, size: size * 0.4, color: colors.accentFlare),
    );
  }
}

/// Title + subtitle row with [EncryptedLockBadge], used for private-send and
/// encrypted-account notices. When [showCard] is true, wraps content in a
/// bordered surface card (home encrypted account footer).
class PrivateActivityNotice extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showCard;

  const PrivateActivityNotice({super.key, required this.title, required this.subtitle, this.showCard = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    final row = Row(
      children: [
        const EncryptedLockBadge(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.bodyLarge.copyWith(color: colors.textContent)),
              const SizedBox(height: 4),
              Text(subtitle, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
      ],
    );

    if (!showCard) return row;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: row,
    );
  }
}
