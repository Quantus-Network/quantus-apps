import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/home_screen.dart';
import 'package:quantus_cold_wallet/screens/welcome_screen.dart';

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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Scaffold(
      body: BaseBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colors.semanticEmber),
                const SizedBox(height: 24),
                Text(
                  'Storage error',
                  style: text.titleScreen.copyWith(color: colors.textContent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: text.body.copyWith(color: colors.textMuted),
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
