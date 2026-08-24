import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';

/// Orange mono "STEP n/3" label shared by the Keystone signing screens.
class KeystoneStepLabel extends ConsumerWidget {
  final int current;
  final int total;

  const KeystoneStepLabel({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return Text(
      l10n.keystoneSignStep(current, total),
      style: context.themeTextV3.labelData.copyWith(color: context.colorsV3.accentFlare),
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
    final ember = context.colorsV3.semanticEmber;
    final warningIcon = SvgPicture.asset(
      'assets/v2/keystone_warning.svg',
      width: 16,
      height: 16,
      colorFilter: ColorFilter.mode(ember, BlendMode.srcIn),
    );

    if (title == null) {
      return QuantusBanner(tone: BannerTone.ember, message: text, leading: warningIcon);
    }

    final colors = context.colorsV3;
    final textTheme = context.themeTextV3;
    final fillEnd = Color.lerp(ember, colors.bgVoid, 0.75)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ember.useOpacity(0.10)),
        borderRadius: context.radiusV3.mdBorder,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ember.useOpacity(0.25), fillEnd.useOpacity(0.25)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              warningIcon,
              const SizedBox(width: 8),
              Text(title!, style: textTheme.body.copyWith(color: ember)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: textTheme.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}
