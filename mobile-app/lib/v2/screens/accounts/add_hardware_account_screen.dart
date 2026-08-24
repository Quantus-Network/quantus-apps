import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/connect_keystone_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Intro screen for adding a Keystone hardware wallet/account.
///
/// Explains what Keystone is, then hands off to [ConnectKeystoneScreen] for
/// the on-device instructions and QR scan.
class AddHardwareAccountScreen extends ConsumerWidget {
  const AddHardwareAccountScreen({super.key, required this.walletIndex, this.isNewWallet = false});

  final int walletIndex;
  final bool isNewWallet;

  static final Uri _keystoneStoreUrl = Uri.parse('https://keyst.one');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final heroRadius = context.radiusV3.smBorder;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.addKeystoneAppBarTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 218,
            decoration: BoxDecoration(
              border: Border.all(color: colors.borderHairline),
              borderRadius: heroRadius,
              color: colors.bgSurface,
            ),
            child: ClipRRect(
              borderRadius: heroRadius,
              child: Image.asset('assets/v2/keystone_hero.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.addKeystoneIntroTitle,
            style: text.titleHero.copyWith(color: colors.textContent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addKeystoneIntroSubtitle,
            style: text.body.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(
              label: l10n.addKeystoneConnectButton,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConnectKeystoneScreen(walletIndex: walletIndex, isNewWallet: isNewWallet),
                ),
              ),
            ),
            const SizedBox(height: 4),
            QuantusButton.simple(
              label: l10n.addKeystoneGetOneLink,
              variant: ButtonVariant.underline,
              textStyle: TextStyle(color: colors.accentFlare),
              onTap: () => launchUrl(_keystoneStoreUrl, mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }
}
