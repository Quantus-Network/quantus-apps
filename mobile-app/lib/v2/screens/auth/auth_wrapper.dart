import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:quantus_sdk/src/ui/components/base_background.dart';
import 'package:quantus_sdk/src/ui/components/loader.dart';
import 'package:quantus_sdk/src/ui/components/quantus_button.dart';

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
      backgroundColor: context.colors.background,
      body: BaseBackground(child: Center(child: Image.asset('assets/v2/auth_wrapper_bracket.png'))),
    );
  }

  Widget _buildLockScreen(BuildContext context, WidgetRef ref, bool isAuthenticating) {
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: BaseBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset('assets/v2/auth_wrapper_bracket.png'),
                  Text(l10n.authAuthorizationRequired, style: context.themeText.lockTitle, textAlign: TextAlign.center),
                ],
              ),
              const SizedBox(height: 60),
              if (isAuthenticating)
                const Loader()
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.themeSize.screenPadding),
                  child: QuantusButton.simple(
                    label: l10n.authUnlockWallet,
                    onTap: () {
                      ref.read(localAuthProvider.notifier).authenticate();
                    },
                    variant: ButtonVariant.secondary,
                  ),
                ),
              const SizedBox(height: 40),
              Text(
                isAuthenticating ? l10n.authAuthenticating : l10n.authUseDeviceBiometricsToUnlock,
                style: context.themeText.smallParagraph?.copyWith(color: context.colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
