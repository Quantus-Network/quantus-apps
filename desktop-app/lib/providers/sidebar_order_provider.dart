import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

/// The order the sidebar's groups were put in, as their [SidebarGroup.orderKey]s,
/// kept for the next start. Empty until a group is moved: the groups are then
/// in their first order ([groupSidebar]).
final sidebarOrderProvider = NotifierProvider<SidebarOrderNotifier, List<String>>(SidebarOrderNotifier.new);

class SidebarOrderNotifier extends Notifier<List<String>> {
  /// Where it is kept between runs, as the groups' keys joined by commas.
  static const settingsKey = 'desktop_sidebar_order';

  @override
  List<String> build() {
    final saved = ref.watch(settingsServiceProvider).getValue(settingsKey);
    if (saved == null) return const [];
    final keys = saved is String
        ? [
            for (final part in saved.split(','))
              if (part.isNotEmpty) part,
          ]
        : null;
    if (keys == null || !keys.every(_isGroupKey)) {
      // A preference of the window's, not the wallet's: the groups are in
      // their first order, as on a first run, and the stray value is reported.
      ref.read(telemetryProvider).sendError('The saved sidebar order is unreadable', error: saved);
      return const [];
    }
    return List.unmodifiable(keys);
  }

  static bool _isGroupKey(String key) => key == SidebarMultisigs.key || RegExp(r'^wallet:\d+$').hasMatch(key);

  /// Keeps [order], the groups' keys top to bottom ([SidebarGroupMover]).
  void keep(List<String> order) => _set(order);

  /// Forgets the wallet at [walletIndex], which is gone: its index goes to
  /// the next wallet added, which takes its place as a new wallet does.
  void forgetWallet(int walletIndex) {
    final key = SidebarWallet.keyOf(walletIndex);
    if (state.contains(key)) _set([...state]..remove(key));
  }

  void _set(List<String> order) {
    state = List.unmodifiable(order);
    unawaited(_save());
  }

  /// A failure is reported: the order stays as it is until the app quits.
  Future<void> _save() async {
    final telemetry = ref.read(telemetryProvider);
    try {
      await ref.read(settingsServiceProvider).setString(settingsKey, state.join(','));
    } catch (e) {
      quantusPrint('Saving the sidebar order failed: $e');
      telemetry.sendError('Saving the sidebar order failed', error: e);
    }
  }
}

/// The sidebar's groups, top to bottom, in the order kept: the multisigs'
/// group while there are multisigs or one is being created. Null until the
/// accounts and the multisigs have loaded.
final sidebarGroupsProvider = Provider<List<SidebarGroup>?>((ref) {
  final accounts = ref.watch(accountsProvider).value;
  final multisigs = ref.watch(multisigAccountsProvider).value;
  if (accounts == null || multisigs == null) return null;
  return groupSidebar(
    accounts: accounts,
    multisigs: multisigs,
    order: ref.watch(sidebarOrderProvider),
    showsMultisigs: ref.watch(creatingMultisigsProvider).isNotEmpty,
  );
});

/// Moves the sidebar's groups among those shown, and keeps the order they
/// are then in ([sidebarOrderProvider]).
final sidebarGroupMoverProvider = Provider<SidebarGroupMover>(SidebarGroupMover.new);

class SidebarGroupMover {
  SidebarGroupMover(this._ref);

  final Ref _ref;

  /// Moves the group kept as [key] [by] places, up when negative. A move past
  /// either end changes nothing.
  void moveBy(String key, int by) {
    final shown = _shown();
    final from = shown.indexOf(key);
    if (from == -1) throw StateError('No group $key in the sidebar to move');
    final to = from + by;
    if (to < 0 || to >= shown.length || to == from) return;
    _keep(shown..insert(to, shown.removeAt(from)));
  }

  /// Puts the group kept as [key] next to the one kept as [beside]: after it,
  /// or before it. Where it already is, nothing changes.
  void place(String key, {required String beside, required bool after}) {
    final moved = _placed(key, beside: beside, after: after);
    if (moved != null) _keep(moved);
  }

  /// Whether putting the group kept as [key] next to [beside] would move it.
  bool wouldPlace(String key, {required String beside, required bool after}) =>
      _placed(key, beside: beside, after: after) != null;

  /// The groups' keys with [key] next to [beside]; null where it is already.
  List<String>? _placed(String key, {required String beside, required bool after}) {
    final shown = _shown();
    if (!shown.contains(key)) throw StateError('No group $key in the sidebar to move');
    if (!shown.contains(beside)) throw StateError('No group $beside in the sidebar to move beside');
    if (key == beside) return null;
    final moved = [...shown]..remove(key);
    moved.insert(moved.indexOf(beside) + (after ? 1 : 0), key);
    return listEquals(moved, shown) ? null : moved;
  }

  /// Whether the group kept as [key] could move [by] places.
  bool canMoveBy(String key, int by) {
    final shown = _shown();
    final to = shown.indexOf(key) + by;
    return shown.contains(key) && to >= 0 && to < shown.length;
  }

  /// The groups' keys as the sidebar shows them now.
  List<String> _shown() {
    final groups = _ref.read(sidebarGroupsProvider);
    if (groups == null) throw StateError("The sidebar's groups have not loaded");
    return [for (final group in groups) group.orderKey];
  }

  void _keep(List<String> order) => _ref.read(sidebarOrderProvider.notifier).keep(order);
}
