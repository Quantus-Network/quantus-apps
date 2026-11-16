import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:yaml/yaml.dart';

/// The font families this app bundles, each with its font files, as declared
/// in its pubspec.
Map<String, List<String>> _bundledFonts() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final fonts = (pubspec['flutter'] as YamlMap)['fonts'] as YamlList? ?? YamlList();
  return {
    for (final family in fonts.cast<YamlMap>())
      family['family'] as String: [
        for (final font in (family['fonts'] as YamlList).cast<YamlMap>()) font['asset'] as String,
      ],
  };
}

void main() {
  // The theme names its fonts by family. A family the app does not bundle is
  // drawn in the system font without any error, which among other things
  // breaks the Welcome page's grid of monospace characters.
  for (final family in {AppTextThemeV3.fontFamily, AppTextThemeV3.fontFamilySecondary}) {
    test('the app bundles the theme\'s "$family" font, in the weights the theme uses', () {
      final files = _bundledFonts()[family];

      expect(files, isNotNull, reason: 'pubspec.yaml declares no "$family" family');
      for (final file in files!) {
        expect(File(file).existsSync(), isTrue, reason: '$file is declared but missing');
      }
      final name = family.replaceAll(' ', '');
      expect(files, containsAll(['assets/fonts/$name-Regular.ttf', 'assets/fonts/$name-Medium.ttf']));
    });
  }
}
