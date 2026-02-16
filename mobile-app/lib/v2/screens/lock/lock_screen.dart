import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(localAuthProvider);

    if (authState.isAuthenticated) {
      // If authenticated, be invisible.
      return const SizedBox.shrink();
    }

    return _buildLockScreen(context, ref, authState.isAuthenticating);
  }

  Widget _buildLockScreen(BuildContext context, WidgetRef ref, bool isAuthenticating) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: GradientBackground(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset('assets/v2/auth_wrapper_bracket.png'),
              Text('Authorization \n Required', style: context.themeText.lockTitle, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
