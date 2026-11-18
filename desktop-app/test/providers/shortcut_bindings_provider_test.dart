import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/providers/shortcut_bindings_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../fakes.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

const _cmdJ = KeyCombo(LogicalKeyboardKey.keyJ, KeyModifiers(meta: true));

void main() {
  late FakeSettingsService settings;
  late _RecordingTelemetry telemetry;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    settings = FakeSettingsService();
    telemetry = _RecordingTelemetry();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  ProviderContainer start() {
    final container = ProviderContainer(
      overrides: [settingsServiceProvider.overrideWithValue(settings), telemetryProvider.overrideWithValue(telemetry)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('with nothing saved, the shortcuts are the platform\'s defaults', () {
    final state = start().read(shortcutBindingsProvider);

    expect(state.bindings, const ShortcutBindings.defaults(isMac: true));
    expect(state.savedWereUnreadable, isFalse);
  });

  test('a change is saved, and is there again at the next start', () async {
    await start().read(shortcutBindingsProvider.notifier).setShortcut(AppCommand.nextSidebarItem, _cmdJ);
    await start().read(shortcutBindingsProvider.notifier).setShortcut(AppCommand.send, null);
    await start()
        .read(shortcutBindingsProvider.notifier)
        .setAccountModifiers(const KeyModifiers(meta: true, alt: true));

    final bindings = start().read(shortcutBindingsProvider).bindings;

    expect(bindings[AppCommand.nextSidebarItem], _cmdJ);
    expect(bindings[AppCommand.send], isNull);
    expect(bindings.accountModifiers, const KeyModifiers(meta: true, alt: true));
  });

  test('a change that is refused throws and leaves the shortcuts and the saved ones as they were', () async {
    final container = start();

    await expectLater(
      container
          .read(shortcutBindingsProvider.notifier)
          .setShortcut(AppCommand.send, const KeyCombo(LogicalKeyboardKey.keyR, KeyModifiers(meta: true))),
      throwsArgumentError,
    );

    expect(container.read(shortcutBindingsProvider).bindings, const ShortcutBindings.defaults(isMac: true));
    expect(settings.strings, isEmpty);
  });

  test('a change that cannot be saved throws and leaves the shortcuts as they were', () async {
    final container = start();
    settings.failNextStringWrite = StateError('disk full');

    await expectLater(
      container.read(shortcutBindingsProvider.notifier).setShortcut(AppCommand.send, _cmdJ),
      throwsStateError,
    );

    expect(container.read(shortcutBindingsProvider).bindings[AppCommand.send], isNot(_cmdJ));
  });

  test('Restore Defaults saves no changes, and the defaults are back', () async {
    final container = start();
    final notifier = container.read(shortcutBindingsProvider.notifier);
    await notifier.setShortcut(AppCommand.nextSidebarItem, _cmdJ);

    await notifier.restoreDefaults();

    expect(container.read(shortcutBindingsProvider).bindings, const ShortcutBindings.defaults(isMac: true));
    expect(start().read(shortcutBindingsProvider).bindings, const ShortcutBindings.defaults(isMac: true));
  });

  test('saved shortcuts that cannot be read give the defaults, say so and report it', () async {
    settings.strings[ShortcutBindingsNotifier.settingsKey] = 'not json';
    final container = start();

    final state = container.read(shortcutBindingsProvider);

    expect(state.bindings, const ShortcutBindings.defaults(isMac: true));
    expect(state.savedWereUnreadable, isTrue);
    expect(telemetry.errors, ['Reading the saved keyboard shortcuts failed']);

    // Saving over them ends the notice.
    await container.read(shortcutBindingsProvider.notifier).restoreDefaults();

    expect(container.read(shortcutBindingsProvider).savedWereUnreadable, isFalse);
  });

  test('saved shortcuts that clash are unreadable too', () {
    settings.strings[ShortcutBindingsNotifier.settingsKey] = jsonEncode({
      'commands': {'send': const KeyCombo(LogicalKeyboardKey.keyR, KeyModifiers(meta: true)).toJson()},
    });

    expect(start().read(shortcutBindingsProvider).savedWereUnreadable, isTrue);
  });

  test('on Windows and Linux the shortcuts are theirs', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    expect(start().read(shortcutBindingsProvider).bindings, const ShortcutBindings.defaults(isMac: false));
  });
}
