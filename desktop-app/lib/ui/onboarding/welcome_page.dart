import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The first page on a device with no wallet: create one or import one.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({
    super.key,
    required this.isCreating,
    required this.error,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  /// Whether a wallet is being created right now.
  final bool isCreating;

  /// Why the last attempt to create a wallet failed, if it did.
  final String? error;
  final VoidCallback onCreateWallet;
  final VoidCallback onImportWallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return OnboardingPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/quantus_orange_logo.png', height: 32),
          const SizedBox(height: 16),
          Text(
            l10n.welcomeTagline,
            textAlign: TextAlign.center,
            style: text.titleHero.copyWith(color: colors.textWhite),
          ),
          const SizedBox(height: 48),
          QuantusButton.simple(label: l10n.welcomeCreateNewWallet, onTap: onCreateWallet, isLoading: isCreating),
          const SizedBox(height: 16),
          QuantusButton.simple(
            label: l10n.welcomeImportWallet,
            onTap: onImportWallet,
            variant: ButtonVariant.staged,
            isDisabled: isCreating,
          ),
          if (error case final error?) ...[
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.semanticEmber),
            ),
          ],
        ],
      ),
    );
  }
}
