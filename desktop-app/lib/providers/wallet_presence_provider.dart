import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:quantus_desktop_wallet/providers/boot_intro_provider.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shortcut_bindings_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/logout_service.dart';

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
  Future<WalletPresence> build() => _check(ref.watch(settingsServiceProvider));

  Future<WalletPresence> _check(SettingsService settings) async {
    if (!await settings.getHasWallet()) return WalletPresence.none;
    // The first wallet on a device is always a software wallet.
    if (await settings.getMnemonic(0) == null) return WalletPresence.phraseMissing;
    return WalletPresence.present;
  }

  /// Checks again, as asked for when the recovery phrase could not be read,
  /// and answers what it found; null when the check failed, which the state
  /// then holds. The state changes only when the answer does, so the same
  /// answer is not reported twice.
  Future<WalletPresence?> checkAgain() async {
    final WalletPresence presence;
    try {
      presence = await _check(ref.read(settingsServiceProvider));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
    if (presence != state.value) state = AsyncData(presence);
    return presence;
  }

  /// Onboarding created or imported a wallet.
  void walletAdded() => state = const AsyncData(WalletPresence.present);

  /// Wipes the wallet and everything stored with it.
  Future<void> wipeWallet() async {
    final introSeen = ref.read(bootIntroSeenProvider);
    // A shortcut still being saved would be written back over the wipe.
    final shortcuts = ref.read(shortcutBindingsProvider.notifier);
    await shortcuts.suspend();
    try {
      await ref.read(logoutServiceProvider).logout();
      // The wipe cleared every setting, this one included.
      if (introSeen) await ref.read(bootIntroSeenProvider.notifier).markSeen();
    } finally {
      shortcuts.resume();
    }
    // The changed keyboard shortcuts went with the settings.
    ref.invalidate(shortcutBindingsProvider);
    // So did the wallets and the multisigs left open.
    ref
      ..invalidate(keptOpenWalletsProvider)
      ..invalidate(keptOpenMultisigsProvider);
    state = const AsyncData(WalletPresence.none);
  }
}
