import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// Whether this device has shown the boot intro. It plays once ever, before
/// the first Welcome.
final bootIntroSeenProvider = NotifierProvider<BootIntroSeenNotifier, bool>(BootIntroSeenNotifier.new);

class BootIntroSeenNotifier extends Notifier<bool> {
  static const settingsKey = 'desktop_boot_intro_seen';

  @override
  bool build() => ref.watch(settingsServiceProvider).getBool(settingsKey) ?? false;

  /// Records the intro as shown. Also called after a wallet wipe, which
  /// clears every setting, to keep an intro already shown from playing again.
  Future<void> markSeen() async {
    state = true;
    await ref.read(settingsServiceProvider).setBool(settingsKey, true);
  }
}
