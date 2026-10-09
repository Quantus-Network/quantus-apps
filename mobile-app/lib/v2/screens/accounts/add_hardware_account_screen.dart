import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/connect_keystone_screen.dart';

/// Intro screen for adding a cold wallet account.
///
/// Explains what a cold wallet is, then hands off to [ConnectKeystoneScreen]
/// for the on-device instructions and QR scan.
class AddHardwareAccountScreen extends ConsumerWidget {
  const AddHardwareAccountScreen({super.key, required this.walletIndex, this.isNewWallet = false});

  final int walletIndex;
  final bool isNewWallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.addKeystoneAppBarTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 218,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: colors.borderHairline),
              borderRadius: context.radiusV3.smBorder,
              color: colors.bgSurface,
            ),
            child: SvgPicture.asset('assets/v2/keystone_qr_code.svg', width: 96, height: 96),
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
        child: QuantusButton.simple(
          label: l10n.addKeystoneConnectButton,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ConnectKeystoneScreen(walletIndex: walletIndex, isNewWallet: isNewWallet),
            ),
          ),
        ),
      ),
    );
  }
}
