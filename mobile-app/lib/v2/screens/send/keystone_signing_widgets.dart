import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';

/// Orange mono "STEP n/3" label, title and instruction that head each Keystone
/// signing screen.
class KeystoneStepHeader extends ConsumerWidget {
  final int current;
  final int total;
  final String title;
  final String instruction;

  const KeystoneStepHeader({
    super.key,
    required this.current,
    required this.total,
    required this.title,
    required this.instruction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.keystoneSignStep(current, total), style: text.labelData.copyWith(color: colors.accentFlare)),
        const SizedBox(height: 12),
        Text(title, style: text.headingRow.copyWith(color: colors.textContent)),
        const SizedBox(height: 8),
        Text(instruction, style: text.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }
}

/// Ember warning card shared by the Keystone verify and reject screens.
class KeystoneWarningCard extends StatelessWidget {
  final String text;
  final String? title;

  const KeystoneWarningCard({super.key, required this.text, this.title});

  @override
  Widget build(BuildContext context) {
    final warningIcon = SvgPicture.asset(
      'assets/v2/keystone_warning.svg',
      width: 16,
      height: 16,
      colorFilter: ColorFilter.mode(context.colorsV3.semanticEmber, BlendMode.srcIn),
    );
    final cardTitle = title;

    if (cardTitle == null) {
      return QuantusBanner(tone: BannerTone.ember, message: text, leading: warningIcon);
    }
    return QuantusBanner.titled(tone: BannerTone.ember, label: cardTitle, message: text, leading: warningIcon);
  }
}
