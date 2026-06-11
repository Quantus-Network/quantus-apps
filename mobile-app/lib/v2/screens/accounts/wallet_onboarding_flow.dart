import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';

/// Refreshes providers, registers notifications, and opens the overview screen.
Future<void> completeWalletOnboarding({
  required WidgetRef ref,
  required BuildContext context,
  required CreatedWalletDetails wallet,
}) async {
  ref.invalidate(accountsProvider);
  ref.invalidate(activeAccountProvider);

  if (ref.read(remoteConfigProvider).enableRemoteNotifications) {
    ref.read(firebaseMessagingServiceProvider).registerDeviceIfPossible();
  }

  if (!context.mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AccountReadyScreen(
        accountId: wallet.accountId,
        accountName: wallet.accountName,
        checksumPhrase: wallet.checksumPhrase,
        origin: AccountReadyOverviewOrigin.walletCreated,
      ),
    ),
    (_) => false,
  );
}
