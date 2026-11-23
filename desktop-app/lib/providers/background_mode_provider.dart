import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Whether this platform can keep the app running with its window closed.
bool get supportsBackgroundMode => defaultTargetPlatform == TargetPlatform.macOS;

/// Whether the person wants the app to keep running when its window closes.
/// It does unless they said otherwise in Settings.
final keepRunningProvider = NotifierProvider<KeepRunningNotifier, bool>(KeepRunningNotifier.new);

class KeepRunningNotifier extends Notifier<bool> {
  /// Where the choice is kept between runs.
  static const settingsKey = 'desktop_keep_running';

  @override
  bool build() => ref.watch(settingsServiceProvider).getBool(settingsKey) ?? true;

  /// Saves the choice. One that cannot be saved is reported and undone, so
  /// the switch never shows what the next start would not.
  Future<void> setEnabled(bool enabled) async {
    final previous = state;
    state = enabled;
    final telemetry = ref.read(telemetryProvider);
    try {
      await ref.read(settingsServiceProvider).setBool(settingsKey, enabled);
    } catch (e) {
      quantusPrint('Saving whether to keep running when closed failed: $e');
      telemetry.sendError('desktop_keep_running_save_failed', error: e);
      if (ref.mounted && state == enabled) state = previous;
    }
  }
}

/// Whether the window is closed with the app still running.
final windowClosedProvider = NotifierProvider<WindowClosedNotifier, bool>(WindowClosedNotifier.new);

class WindowClosedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool isClosed) => state = isClosed;
}

/// Who has work under way that no pending record shows, such as a send being
/// approved, signed or proved.
final workHoldsProvider = NotifierProvider<WorkHoldsNotifier, Set<Object>>(WorkHoldsNotifier.new);

class WorkHoldsNotifier extends Notifier<Set<Object>> {
  @override
  Set<Object> build() => const {};

  void hold(Object holder) => state = {...state, holder};

  void release(Object holder) {
    if (!ref.mounted || !state.contains(holder)) return;
    state = {...state}..remove(holder);
  }
}
