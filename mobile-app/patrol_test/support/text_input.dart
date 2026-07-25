import 'package:flutter/widgets.dart';
import 'package:patrol/patrol.dart';

/// Types [text] into [fieldKey] one character at a time.
///
/// Bulk [PatrolFinder.enterText] on an unfocused field uses Flutter's test
/// binding, which can update the controller without firing [TextField.onChanged].
/// Stateful forms that derive side effects from `onChanged` (such as the send
/// amount screen parsing into a [BigInt]) stay stale unless input mimics typing.
Future<void> typeTextIntoField(
  PatrolIntegrationTester $,
  Key fieldKey,
  String text,
) async {
  await $(fieldKey).tap();

  final buffer = StringBuffer();
  for (final char in text.split('')) {
    if (char.isEmpty) {
      continue;
    }
    buffer.write(char);
    await $(fieldKey).enterText(buffer.toString(), hideKeyboard: false);
  }

  // Dismiss the keyboard without re-applying a differently formatted string.
  await $(fieldKey).enterText(buffer.toString());
}
