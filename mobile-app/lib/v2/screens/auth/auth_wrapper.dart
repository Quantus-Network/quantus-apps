import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_spacing.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
      body: GradientBackground(child: Center(child: Image.asset('assets/v2/auth_wrapper_bracket.png'))),
    );
  }

  Widget _buildLockScreen(BuildContext context, WidgetRef ref, bool isAuthenticating) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: GradientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset('assets/v2/auth_wrapper_bracket.png'),
                  Text('Authorization \n Required', style: context.themeText.lockTitle, textAlign: TextAlign.center),
                ],
              ),
              const SizedBox(height: 60),
              if (isAuthenticating)
                const CircularProgressIndicator()
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.themeSize.screenPadding),
                  child: GlassButton.simple(
                    label: 'Unlock Wallet',
                    onTap: () {
                      ref.read(localAuthProvider.notifier).authenticate();
                    },
                    variant: ButtonVariant.secondary,
                  ),
                ),
              const SizedBox(height: 40),
              Text(
                isAuthenticating ? 'Authenticating...' : 'Use device biometrics to unlock',
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
