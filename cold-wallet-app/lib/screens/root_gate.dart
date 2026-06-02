import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/base_background.dart';
import 'package:quantus_cold_wallet/components/loader.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/home_screen.dart';
import 'package:quantus_cold_wallet/screens/welcome_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Routes the app to setup, lock, or home based on the wallet status.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(walletControllerProvider.select((s) => s.status));
    final error = ref.watch(walletControllerProvider.select((s) => s.error));

    switch (status) {
      case WalletStatus.initializing:
        if (error != null) return _InitError(message: error);
        return const Scaffold(
          body: BaseBackground(child: Center(child: Loader(size: 24))),
        );
      case WalletStatus.needsSetup:
        return const WelcomeScreen();
      // When locked, the home route renders underneath the full-screen
      // LockOverlay (see app.dart) until the user unlocks.
      case WalletStatus.locked:
      case WalletStatus.unlocked:
        return const HomeScreen();
    }
  }
}

class _InitError extends ConsumerWidget {
  final String message;
  const _InitError({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    return Scaffold(
      body: BaseBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colors.error),
                const SizedBox(height: 24),
                Text(
                  'Storage error',
                  style: text.mediumTitle?.copyWith(color: colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: text.smallParagraph?.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                QuantusButton.simple(
                  label: 'Retry',
                  onTap: () => ref.read(walletControllerProvider.notifier).retryInit(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
