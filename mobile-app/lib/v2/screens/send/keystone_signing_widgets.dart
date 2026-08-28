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
