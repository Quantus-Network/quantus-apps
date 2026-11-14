import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// Whether this device holds a wallet. Checked once at start, then kept in
/// step by the flows that add or remove the wallet.
///
/// A failed check is not repeated: reading the keychain again could prompt
/// the user for it again.
final walletPresenceProvider = AsyncNotifierProvider<WalletPresenceNotifier, WalletPresence>(
  WalletPresenceNotifier.new,
  retry: (_, _) => null,
);

class WalletPresenceNotifier extends AsyncNotifier<WalletPresence> {
  @override
  Future<WalletPresence> build() async {
    final settings = ref.watch(settingsServiceProvider);
    if (!await settings.getHasWallet()) return WalletPresence.none;
    // The first wallet on a device is always a software wallet.
    if (await settings.getMnemonic(0) == null) return WalletPresence.phraseMissing;
    return WalletPresence.present;
  }

  /// Onboarding created or imported a wallet.
  void walletAdded() => state = const AsyncData(WalletPresence.present);

  /// The wallet was wiped.
  void walletRemoved() => state = const AsyncData(WalletPresence.none);
}
