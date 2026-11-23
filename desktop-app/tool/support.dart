import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
  }
  await loader.load();
}

/// Where pub put [package].
String _packageRoot(String package) {
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (config['packages'] as List).cast<Map<String, dynamic>>().singleWhere((p) => p['name'] == package);
  return Uri.parse(entry['rootUri'] as String).toFilePath();
}

/// Loads the fonts the app ships with, in place of the test font. Call it
/// from `setUpAll`: inside a test the clock is faked and loading never ends.
Future<void> loadRealFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  await _loadFont('Geist', ['assets/fonts/Geist-Regular.ttf', 'assets/fonts/Geist-Medium.ttf']);
  await _loadFont('Geist Mono', ['assets/fonts/GeistMono-Regular.ttf', 'assets/fonts/GeistMono-Medium.ttf']);
  await _loadFont('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  await _loadFont('packages/cupertino_icons/CupertinoIcons', [
    '${_packageRoot('cupertino_icons')}/assets/CupertinoIcons.ttf',
  ]);
}
