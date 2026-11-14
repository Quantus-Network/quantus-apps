import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// Announces a wallet that was just created, and the two accounts it starts
/// with: [account] and the encrypted account beside it.
class WalletCreatedPage extends ConsumerWidget {
  const WalletCreatedPage({super.key, required this.account, required this.onGoToWallet});

  final Account account;
  final VoidCallback onGoToWallet;

  static const double _ringSize = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return OnboardingPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _ringSize,
            height: _ringSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.semanticSage, width: 2),
            ),
            child: Icon(Icons.check_rounded, size: 28, color: colors.semanticSage),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.accountReadyWalletCreated,
            textAlign: TextAlign.center,
            style: text.titleSuccess.copyWith(color: colors.textContent),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.accountReadyTwoAccountsCreated,
            textAlign: TextAlign.center,
            style: text.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 32),
          InfoCard(
            leading: AccountBadge(name: account.name),
            title: account.name,
            description: l10n.accountReadyMainAccountDescription,
          ),
          const SizedBox(height: 12),
          InfoCard(
            leading: const EncryptedLockBadge(),
            title: l10n.createAccountEncryptedDefaultName,
            description: l10n.accountReadyEncryptedAccountDescription,
          ),
          const SizedBox(height: 32),
          QuantusButton.simple(label: l10n.accountReadyGoToWallet, onTap: onGoToWallet),
        ],
      ),
    );
  }
}
