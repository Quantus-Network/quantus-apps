import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// The wallet the active account is in, where New Account adds one: a
/// multisig is in the wallet of the account that owns it, though the sidebar
/// lists it under the multisigs ([activeRowWalletIndexProvider]). Null while
/// they load, and for a multisig in no wallet here.
final activeWalletIndexProvider = Provider<int?>((ref) {
  final activeId = ref.watch(activeAccountProvider).value?.account.accountId;
  final accounts = ref.watch(accountsProvider).value;
  final multisigs = ref.watch(multisigAccountsProvider).value;
  if (activeId == null || accounts == null || multisigs == null) return null;
  final wallets = groupWallets(accounts: accounts, multisigs: multisigs).wallets;
  return wallets.where((wallet) => wallet.contains(activeId)).firstOrNull?.walletIndex;
});

/// Whether the active account is a multisig, whose row is under the
/// multisigs' heading. False while it loads.
final activeIsMultisigProvider = Provider<bool>(
  (ref) => ref.watch(activeAccountProvider).value is MultisigDisplayAccount,
);

/// The wallet whose heading holds the active account's row: none for a
/// multisig, which sits under the multisigs' heading, and none while they load.
final activeRowWalletIndexProvider = Provider<int?>(
  (ref) => ref.watch(activeIsMultisigProvider) ? null : ref.watch(activeWalletIndexProvider),
);

/// The wallets left open in the sidebar, kept for the next start. The active
/// account's wallet shows open whether or not it is among them
/// ([openWalletsProvider]).
final keptOpenWalletsProvider = NotifierProvider<KeptOpenWalletsNotifier, Set<int>>(KeptOpenWalletsNotifier.new);

class KeptOpenWalletsNotifier extends Notifier<Set<int>> {
  /// Where they are kept between runs, as their indexes joined by commas.
  static const settingsKey = 'desktop_open_wallets';

  @override
  Set<int> build() {
    final saved = ref.watch(settingsServiceProvider).getValue(settingsKey);
    if (saved == null) return const {};
    final indexes = saved is String
        ? [
            for (final part in saved.split(','))
              if (part.isNotEmpty) int.tryParse(part),
          ]
        : null;
    if (indexes == null || indexes.contains(null)) {
      // A preference of the window's, not the wallet's: it opens as it would
      // on a first run, and the stray value is reported.
      ref.read(telemetryProvider).sendError('The saved open wallets are unreadable', error: saved);
      return const {};
    }
    return Set.unmodifiable(indexes.nonNulls);
  }

  /// Opens the wallet at [walletIndex], or closes it. The active account's
  /// wallet stays open, so it is always clear which wallet that account is in.
  void toggle(int walletIndex) {
    if (ref.read(activeRowWalletIndexProvider) == walletIndex) return;
    _set(state.contains(walletIndex) ? state.difference({walletIndex}) : {...state, walletIndex});
  }

  /// Keeps the wallet at [walletIndex] open once its account stops being the
  /// active one, so the rows around the one clicked do not move.
  void keepOpen(int walletIndex) {
    if (!state.contains(walletIndex)) _set({...state, walletIndex});
  }

  /// Forgets the wallet at [walletIndex], which is gone: its index goes to
  /// the next wallet added.
  void forget(int walletIndex) {
    if (state.contains(walletIndex)) _set(state.difference({walletIndex}));
  }

  void _set(Set<int> wallets) {
    state = Set.unmodifiable(wallets);
    unawaited(_save());
  }

  /// A failure is reported: the wallets stay as they are until the app quits.
  Future<void> _save() async {
    final telemetry = ref.read(telemetryProvider);
    try {
      await ref.read(settingsServiceProvider).setString(settingsKey, (state.toList()..sort()).join(','));
    } catch (e) {
      quantusPrint('Saving the open wallets failed: $e');
      telemetry.sendError('Saving the open wallets failed', error: e);
    }
  }
}

/// The wallets showing open in the sidebar: those left open, and the one
/// holding the active account's row.
final openWalletsProvider = Provider<Set<int>>((ref) {
  final active = ref.watch(activeRowWalletIndexProvider);
  return {...ref.watch(keptOpenWalletsProvider), ?active};
});

/// Whether the multisigs were left open in the sidebar, kept for the next
/// start. They show open while one of them is the active account whether or
/// not they were ([multisigsOpenProvider]).
final keptOpenMultisigsProvider = NotifierProvider<KeptOpenMultisigsNotifier, bool>(KeptOpenMultisigsNotifier.new);

class KeptOpenMultisigsNotifier extends Notifier<bool> {
  /// Where it is kept between runs, as a flag.
  static const settingsKey = 'desktop_multisigs_open';

  @override
  bool build() {
    final saved = ref.watch(settingsServiceProvider).getValue(settingsKey);
    if (saved == null || saved is bool) return saved == true;
    // A preference of the window's, not the wallet's: they start closed, as
    // on a first run, and the stray value is reported.
    ref.read(telemetryProvider).sendError('The saved open multisigs are unreadable', error: saved);
    return false;
  }

  /// Opens the multisigs, or closes them. While one of them is the active
  /// account they stay open, so it is always clear where that account is.
  void toggle() {
    if (ref.read(activeIsMultisigProvider)) return;
    _set(!state);
  }

  /// Keeps the multisigs open: once a multisig stops being the active
  /// account, so the rows around the one clicked do not move, and once one
  /// is added or being created, so it shows.
  void keepOpen() {
    if (!state) _set(true);
  }

  void _set(bool open) {
    state = open;
    unawaited(_save());
  }

  /// A failure is reported: they stay as they are until the app quits.
  Future<void> _save() async {
    final telemetry = ref.read(telemetryProvider);
    try {
      await ref.read(settingsServiceProvider).setBool(settingsKey, state);
    } catch (e) {
      quantusPrint('Saving the open multisigs failed: $e');
      telemetry.sendError('Saving the open multisigs failed', error: e);
    }
  }
}

/// Whether the multisigs show open in the sidebar: left open, or holding the
/// active account.
final multisigsOpenProvider = Provider<bool>(
  (ref) => ref.watch(keptOpenMultisigsProvider) || ref.watch(activeIsMultisigProvider),
);

/// The accounts with a row showing in the sidebar, top to bottom: those of the
/// open wallets, then the multisigs while they are open.
final visibleSidebarAccountsProvider = Provider<List<DisplayAccount>>((ref) {
  final accounts = ref.watch(accountsProvider).value;
  final multisigs = ref.watch(multisigAccountsProvider).value;
  if (accounts == null || multisigs == null) return const [];
  final open = ref.watch(openWalletsProvider);
  final groups = groupSidebar(accounts: accounts, multisigs: multisigs);
  return [
    for (final wallet in groups.wallets)
      if (open.contains(wallet.walletIndex)) ...walletAccountsInOrder(wallet),
    if (ref.watch(multisigsOpenProvider))
      for (final multisig in groups.multisigs) MultisigDisplayAccount(multisig),
  ];
});
