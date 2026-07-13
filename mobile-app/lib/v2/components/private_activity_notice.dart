import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Circular lock badge used for encrypted / private UI (always Quantus orange).
class EncryptedLockBadge extends StatelessWidget {
  final double size;

  const EncryptedLockBadge({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.sheetBackground,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: colors.borderButton),
      ),
      child: Icon(Icons.lock_outline, size: size * 0.4, color: colors.accentOrange),
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
    final colors = context.colors;
    final text = context.themeText;

    final row = Row(
      children: [
        const EncryptedLockBadge(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.paragraph?.copyWith(color: colors.textMuted, height: 1.0)),
              const SizedBox(height: 4),
              Text(subtitle, style: text.detail?.copyWith(color: const Color(0xFF666666), height: 1.0)),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderButton),
      ),
      child: row,
    );
  }
}
