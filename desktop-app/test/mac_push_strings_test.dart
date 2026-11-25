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
  'desktopNotificationProposalNewTitle',
  'desktopNotificationProposalSignedTitle',
  'desktopNotificationProposalReadyTitle',
  'desktopNotificationProposalExecutedTitle',
  'desktopNotificationProposalFailedTitle',
  'desktopNotificationProposalCancelledTitle',
  'desktopNotificationProposalRemovedTitle',
  'desktopNotificationProposalCreatedBody',
  'desktopNotificationProposalOtherBody',
];

/// What the app's [words] are in a `.strings` file. The app fills in each of
/// [placeholders] by name; macOS fills in the values the push service sends,
/// in the order the app's own code gives them: `%@` for a single one, and
/// `%1$@`, `%2$@` by position for several, which a language may reorder.
String _forMac(String words, List<String> placeholders) {
  var said = words;
  for (final (i, name) in placeholders.indexed) {
    expect('{$name}'.allMatches(said), hasLength(1), reason: '"$words" takes {$name} once');
    said = said.replaceAll('{$name}', placeholders.length == 1 ? '%@' : '%${i + 1}\$@');
  }
  expect(said, isNot(contains('{')), reason: '"$words" takes only ${placeholders.join(', ')}');
  return said;
}

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
      Map<String, dynamic> arb(String of) =>
          jsonDecode(File('../wallet_core/lib/l10n/app_$of.arb').readAsStringSync()) as Map<String, dynamic>;
      final app = arb(language);
      // The English file is the one that says what each string takes, in the
      // order the app's code and the push service give the values.
      final template = arb('en');
      final mac = _strings('macos/Runner/$language.lproj/Localizable.strings');

      expect(mac.keys, unorderedEquals(_pushedKeys));
      for (final key in _pushedKeys) {
        final described = template['@$key'] as Map<String, dynamic>?;
        final placeholders = (described?['placeholders'] as Map<String, dynamic>? ?? const {}).keys.toList();
        expect(mac[key], _forMac(app[key] as String, placeholders), reason: key);
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
