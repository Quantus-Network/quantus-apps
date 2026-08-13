import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
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
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.addKeystoneAppBarTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 218,
            decoration: BoxDecoration(
              border: Border.all(color: colors.textPrimary.useOpacity(0.07)),
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.sheetBackground, colors.surfaceHero],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/v2/keystone_hero.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.addKeystoneIntroTitle,
            style: text.mediumTitle?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addKeystoneIntroSubtitle,
            style: text.smallParagraph?.copyWith(color: colors.textSubtle),
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
              textStyle: TextStyle(color: colors.accentOrange),
              onTap: () => launchUrl(_keystoneStoreUrl, mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }
}
