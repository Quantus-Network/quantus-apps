import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/screens/create/wallet_ready_screen.dart';
import 'package:resonance_network_wallet/v2/screens/import/import_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class WelcomeScreenV2 extends StatelessWidget {
  const WelcomeScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final isTablet = context.isTablet;

    final background = isTablet
        ? const GradientBackground(child: SizedBox.expand())
        : Image.asset('assets/v2/welcome_screen_bg_image.jpg', fit: BoxFit.cover) as Widget;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          background,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  Image.asset('assets/v2/quantus_white_logo.png', height: 40),
                  const SizedBox(height: 24),
                  Text(
                    'Quantum Secure Your Crypto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // custom text style for the welcome screen
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassContainer(
                    asset: GlassContainer.wideAsset,
                    filled: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'create_wallet'),
                        builder: (_) => const WalletReadyScreenV2(),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Create New Wallet',
                        style: text.paragraph?.copyWith(fontWeight: FontWeight.w500, color: colors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassContainer(
                    asset: GlassContainer.wideClearAsset,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'import_wallet'),
                        builder: (_) => const ImportWalletScreenV2(),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Import Existing Wallet',
                        style: text.paragraph?.copyWith(fontWeight: FontWeight.w500, color: colors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
