import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/utils/serial_queue.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

/// The keyboard shortcuts in use, and whether the saved ones could be read.
@immutable
class ShortcutSettings {
  const ShortcutSettings(this.bindings, {this.savedWereUnreadable = false});

  final ShortcutBindings bindings;

  /// The saved shortcuts could not be read at start, so [bindings] are the
  /// defaults. Settings says so until a change is saved over them.
  final bool savedWereUnreadable;
}

/// The app's keyboard shortcuts: the platform's defaults with what the person
/// changed in Settings, kept in the device's settings.
final shortcutBindingsProvider = NotifierProvider<ShortcutBindingsNotifier, ShortcutSettings>(
  ShortcutBindingsNotifier.new,
);

class ShortcutBindingsNotifier extends Notifier<ShortcutSettings> {
  static const settingsKey = 'desktop_keyboard_shortcuts';

  /// The changes asked for, saved one at a time.
  final _changes = SerialQueue();

  @override
  ShortcutSettings build() {
    // The Mac's shortcuts use ⌘, as its menus are the system's.
    final defaults = ShortcutBindings.defaults(isMac: defaultTargetPlatform == TargetPlatform.macOS);
    final saved = ref.watch(settingsServiceProvider).getString(settingsKey);
    if (saved == null) return ShortcutSettings(defaults);
    try {
      final json = jsonDecode(saved);
      if (json is! Map<String, Object?>) throw FormatException('The saved shortcuts are not a map: $saved');
      return ShortcutSettings(ShortcutBindings.fromJson(json, isMac: defaults.isMac));
    } on FormatException catch (e) {
      // Not worth stopping the app for: the defaults work, and Settings says
      // the saved ones were lost.
      quantusPrint('Reading the saved keyboard shortcuts failed: $e');
      ref.read(telemetryProvider).sendError('Reading the saved keyboard shortcuts failed', error: e);
      return ShortcutSettings(defaults, savedWereUnreadable: true);
    }
  }

  /// Gives [command] the shortcut [combo], or none when it is null. Throws an
  /// [ArgumentError] when [combo] is refused ([ShortcutBindings.refusal]), and
  /// whatever saving it threw; the shortcuts are then unchanged.
  Future<void> setShortcut(AppCommand command, KeyCombo? combo) =>
      _change((bindings) => bindings.withShortcut(command, combo));

  /// Makes [modifiers] the account keys. Throws as [setShortcut] does.
  Future<void> setAccountModifiers(KeyModifiers modifiers) =>
      _change((bindings) => bindings.withAccountModifiers(modifiers));

  /// Puts back every shortcut the app ships with.
  Future<void> restoreDefaults() => _change((bindings) => ShortcutBindings.defaults(isMac: bindings.isMac));

  /// Makes [change] to the shortcuts and saves them, once the changes asked
  /// for before it have been saved: each is made to what the one before it
  /// left, so a change still being saved is not lost to the next.
  Future<void> _change(ShortcutBindings Function(ShortcutBindings bindings) change) => _changes.run(() async {
    if (!ref.mounted) return;
    final bindings = change(state.bindings);
    await ref.read(settingsServiceProvider).setString(settingsKey, jsonEncode(bindings.toJson()));
    if (!ref.mounted) return;
    state = ShortcutSettings(bindings);
  });
}

/// Whether a shortcut in Settings is waiting for new keys. Meanwhile the
/// menus have no keys, so the keys pressed reach it and not a command.
final isRecordingShortcutProvider = NotifierProvider<RecordingShortcutNotifier, bool>(RecordingShortcutNotifier.new);

class RecordingShortcutNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;

  /// Gives the menus their keys back. Once the app is gone there are none.
  void stop() {
    if (ref.mounted) state = false;
  }
}
