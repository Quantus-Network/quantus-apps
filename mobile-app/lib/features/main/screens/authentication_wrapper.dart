import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';

class AuthenticationWrapper extends ConsumerWidget {
  const AuthenticationWrapper({super.key});

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
    return ScaffoldBase(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Authentication Required', style: context.themeText.lockTitle),
            const SizedBox(height: 30),
            if (isAuthenticating)
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(context.themeColors.circularLoader))
            else
              IconButton(
                icon: const Icon(Icons.fingerprint, size: 64),
                color: context.themeColors.circularLoader,
                onPressed: () {
                  ref.read(localAuthProvider.notifier).authenticate();
                },
              ),
          ],
        ),
      ),
    );
  }
}
