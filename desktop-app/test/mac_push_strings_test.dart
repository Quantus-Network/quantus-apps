import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The keys the push service sends a Mac instead of text. macOS shows a
/// pushed notification by itself, while the app is closed, and looks each key
/// up in the app's own `Localizable.strings`.
const _pushedKeys = [
  'desktopNotificationReceivedTitle',
  'desktopNotificationReceivedBody',
  'desktopNotificationIncomingTitle',
  'desktopNotificationIncomingBody',
];

/// The entries of a `.strings` file: `"key" = "value";` lines.
Map<String, String> _strings(String path) => {
  for (final match in RegExp(
    r'^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";$',
    multiLine: true,
  ).allMatches(File(path).readAsStringSync()))
    match.group(1)!: match.group(2)!,
};

void main() {
  for (final language in ['en', 'id']) {
    test('what a closed Mac is shown in "$language" is what the running app says, word for word', () {
      final app =
          jsonDecode(File('../wallet_core/lib/l10n/app_$language.arb').readAsStringSync()) as Map<String, dynamic>;
      final mac = _strings('macos/Runner/$language.lproj/Localizable.strings');

      expect(mac.keys, unorderedEquals(_pushedKeys));
      for (final key in _pushedKeys) {
        // The app fills in one placeholder by name; macOS fills in `%@`.
        final said = (app[key] as String).replaceAll(RegExp(r'\{\w+\}'), '%@');
        expect('%@'.allMatches(said), hasLength(1), reason: '$key takes one value');
        expect(mac[key], said, reason: key);
      }
    });
  }

  test('the Mac\'s strings are part of the app that is built', () {
    final project = File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(project, contains('Localizable.strings in Resources'));
    expect(project, contains('path = en.lproj/Localizable.strings'));
    expect(project, contains('path = id.lproj/Localizable.strings'));
    expect(project, contains('PushNotifications.swift in Sources'));
  });
}
