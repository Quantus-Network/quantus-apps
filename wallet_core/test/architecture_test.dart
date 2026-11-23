import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// wallet_core is shared by the mobile and desktop apps, so it must not pull in
/// mobile-only plugins or depend on an app package. Those integrations stay in
/// the apps and reach wallet_core through interfaces.
const _forbiddenPackages = [
  'firebase_core',
  'firebase_messaging',
  'local_auth',
  'mobile_scanner',
  'image_picker',
  'app_links',
  'flutter_local_notifications',
  'swap_live_activity_channel',
  'play_install_referrer',
  'resonance_network_wallet',
];

final _directiveUri = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

bool _isForbidden(String uri) =>
    _forbiddenPackages.any((p) => uri == 'package:$p' || uri.startsWith('package:$p/')) ||
    uri.startsWith('package:firebase_');

void main() {
  test('wallet_core_has_no_mobile_dependencies: lib/ imports no mobile-only or app package', () {
    final dartFiles = Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(dartFiles, isNotEmpty, reason: 'lib/ has no Dart files; the check would pass vacuously');

    final violations = <String>[];
    for (final file in dartFiles) {
      for (final match in _directiveUri.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (_isForbidden(uri)) violations.add('${file.path}: $uri');
      }
    }

    expect(violations, isEmpty, reason: 'Forbidden imports in wallet_core:\n${violations.join('\n')}');
  });

  test('wallet_core_has_no_mobile_dependencies: pubspec declares no mobile-only or app package', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final declared = <String>[
      ...((pubspec['dependencies'] as YamlMap?)?.keys.cast<String>() ?? const []),
      ...((pubspec['dev_dependencies'] as YamlMap?)?.keys.cast<String>() ?? const []),
    ];

    final violations = declared.where((name) => _isForbidden('package:$name')).toList();

    expect(violations, isEmpty, reason: 'Forbidden dependencies in wallet_core/pubspec.yaml: $violations');
  });
}
