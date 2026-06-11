import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/secure_element_warning_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref, {required bool isImport}) async {
    final auth = ref.read(walletControllerProvider.notifier).auth;
    final secure = await auth.isDeviceSecure();
    if (!context.mounted) return;
    if (!secure) {
      final proceed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SecureElementWarningScreen()),
      );
      if (proceed != true || !context.mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => isImport ? const ImportWalletScreen() : const CreateWalletScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Image.asset('assets/v2/uppercase_q.png', height: 96),
          const SizedBox(height: 32),
          Text(
            'Quantus Cold Wallet',
            style: text.largeTitle?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'An air-gapped signer for the Quantus network. This device never touches the internet.',
            style: text.paragraph?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(label: 'Create new wallet', onTap: () => _start(context, ref, isImport: false)),
            const SizedBox(height: 12),
            QuantusButton.simple(
              label: 'Import wallet',
              variant: ButtonVariant.secondary,
              onTap: () => _start(context, ref, isImport: true),
            ),
          ],
        ),
      ),
    );
  }
}
