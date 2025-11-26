import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_and_backup_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/import_wallet_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final halfScreen = MediaQuery.of(context).size.height * 0.5;

    return ScaffoldBase(
      decorations: [
        const Positioned(top: 60, left: -30, child: Sphere(variant: 1, size: 144.23)),
        Positioned(top: halfScreen, left: 60, child: const Sphere(variant: 2, size: 89.57)),
        Positioned(top: halfScreen, right: -50, child: const Sphere(variant: 2, size: 194)),
        const Positioned(bottom: -32, right: 20, child: Sphere(variant: 6, size: 194)),
      ],
      child: Column(
        children: [
          SizedBox(height: context.isSmallHeight ? 47.5 : 77.5),
          Text('Welcome to', textAlign: TextAlign.center, style: context.themeText.smallTitle),
          const SizedBox(height: 36),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/quantus_logo.svg',
                  height: context.themeSize.logoHeight,
                  fit: BoxFit.fitHeight,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Text('Quantum-Secure Your crypto', textAlign: TextAlign.center, style: context.themeText.smallTitle),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: 343,
            child: Text(
              'Create a new wallet or import an existing one to get started',
              textAlign: TextAlign.center,
              style: context.themeText.paragraph,
            ),
          ),
          SizedBox(height: context.isSmallHeight ? 64.5 : 104.5),
          Button(
            variant: ButtonVariant.primary,
            label: 'Create New Wallet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'create_wallet'),
                  builder: (context) => const CreateWalletAndBackupScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          Button(
            label: 'Import Wallet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'import_wallet'),
                  builder: (context) => const ImportWalletScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
