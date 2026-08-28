import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(localAuthProvider);

    if (!authState.isAuthenticated) {
      return _buildLockScreen(context, ref, authState.isAuthenticating);
    }

    if (authState.isVisuallyLocked) {
      return _buildPrivacyOverlay(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildPrivacyOverlay(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorsV3.bgVoid,
      body: BaseBackground(child: Center(child: Image.asset('assets/v2/auth_wrapper_bracket.png'))),
    );
  }

  Widget _buildLockScreen(BuildContext context, WidgetRef ref, bool isAuthenticating) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Scaffold(
      backgroundColor: colors.bgVoid,
      body: BaseBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset('assets/v2/auth_wrapper_bracket.png'),
                  Text(
                    l10n.authAuthorizationRequired,
                    style: text.titleHero.copyWith(color: colors.textContent),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 60),
              if (isAuthenticating)
                const Loader()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: QuantusButton.simple(
                    label: l10n.authUnlockWallet,
                    onTap: () {
                      ref.read(localAuthProvider.notifier).authenticate();
                    },
                    variant: ButtonVariant.staged,
                  ),
                ),
              const SizedBox(height: 40),
              Text(
                isAuthenticating ? l10n.authAuthenticating : l10n.authUseDeviceBiometricsToUnlock,
                style: text.body.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
