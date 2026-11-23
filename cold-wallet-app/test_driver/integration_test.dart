import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves every screenshot the walkthrough takes under SHOTS_DIR (default
/// `screenshots/` in the package).
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Platform.environment['SHOTS_DIR'] ?? 'screenshots';
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return true;
  },
);
