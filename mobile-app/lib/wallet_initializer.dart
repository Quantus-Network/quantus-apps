import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/services/logout_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';

class WalletInitializer extends ConsumerStatefulWidget {
  const WalletInitializer({super.key});

  @override
  ConsumerState<WalletInitializer> createState() => WalletInitializerState();
}

class WalletInitializerState extends ConsumerState<WalletInitializer> {
  bool _loading = true;
  bool _walletExists = false;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    final hasWallet = await _settingsService.getHasWallet();

    if (hasWallet) {
      final mnemonic = await _settingsService.getMnemonic(0);
      if (mnemonic == null) {
        TelemetryService().sendEvent('user_lost_mnemonic');
        if (mounted) await _showMnemonicLostDialog();
        return;
      }
    }

    setState(() {
      _walletExists = hasWallet;
      _loading = false;
    });
  }

  Future<void> _showMnemonicLostDialog() async {
    final l10n = ref.read(l10nProvider);

    await BottomSheetContainer.show(
      context,
      builder: (ctx) => BottomSheetContainer(
        title: l10n.walletInitErrorTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.walletInitErrorMessage, style: ctx.themeText.smallParagraph),
            const SizedBox(height: 32),
            QuantusButton.simple(
              label: l10n.walletInitErrorButtonLabel,
              onTap: () => Navigator.pop(ctx),
              variant: ButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
    if (mounted) ref.read(logoutServiceProvider).logout(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ScaffoldBase(mainContent: Center(child: CircularProgressIndicator()));
    }

    if (_walletExists) {
      return const HomeScreen();
    } else {
      return const WelcomeScreenV2();
    }
  }
}
