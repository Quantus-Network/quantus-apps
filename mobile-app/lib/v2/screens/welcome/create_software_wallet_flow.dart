import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';

/// Creates a software wallet and lands on the account-ready page. Failures
/// surface as a toaster; callers only track loading state.
Future<void> createSoftwareWalletFlow(BuildContext context, WidgetRef ref) async {
  try {
    final account = await createSoftwareWallet(ref);
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AccountReadyScreen(
          accountId: account.accountId,
          accountName: account.name,
          origin: AccountReadyOverviewOrigin.walletCreated,
        ),
      ),
      (_) => false,
    );
  } catch (e) {
    quantusPrint('Wallet creation failed: $e');
    if (context.mounted) {
      context.showErrorToaster(message: ref.read(l10nProvider).createWalletRecoveryPhraseSaveError('$e'));
    }
  }
}
