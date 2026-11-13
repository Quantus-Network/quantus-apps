import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The desktop app ships on macOS, Windows and Linux and shares code with the
/// mobile app only through quantus_sdk and wallet_core. A Flutter plugin that
/// lacks one of the three platforms builds everywhere but throws
/// MissingPluginException where it is missing, so every plugin pub resolves
/// for this app must implement all three.
const _desktopPlatforms = ['macos', 'windows', 'linux'];

const _mobileAppPackage = 'resonance_network_wallet';

/// Plugins in the dependency graph that are known to lack a desktop platform,
/// with why each is tolerated. Every entry is a feature that fails at runtime
/// on the missing platforms, so the list must stay as short as it can be.
const _knownUnsupportedPlugins = {
  'mobile_scanner':
      'Comes with quantus_sdk (QuantusScanner). It has no Windows or Linux implementation, so the desktop app '
      'must not open the camera scanner there until scanning sits behind an interface.',
};

final _directiveUri = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

/// The pubspec of every package pub resolved for this app, by package name.
Map<String, YamlMap> _resolvedPubspecs() {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final package in (config['packages'] as List).cast<Map<String, dynamic>>())
      package['name'] as String:
          loadYaml(
                File(
                  '${Directory.fromUri(configFile.uri.resolve(package['rootUri'] as String)).path}/pubspec.yaml',
                ).readAsStringSync(),
              )
              as YamlMap,
  };
}

YamlMap? _pluginSection(YamlMap pubspec) {
  final flutter = pubspec['flutter'];
  final plugin = flutter is YamlMap ? flutter['plugin'] : null;
  return plugin is YamlMap ? plugin : null;
}

YamlMap? _pluginPlatforms(YamlMap pubspec) {
  final platforms = _pluginSection(pubspec)?['platforms'];
  return platforms is YamlMap ? platforms : null;
}

/// Packages that implement another plugin for a single platform: they declare
/// `implements`, or a plugin names them as a platform's `default_package`.
/// They and their own dependencies only run on that platform.
Set<String> _platformImplementations(Map<String, YamlMap> pubspecs) => {
  for (final MapEntry(key: name, value: pubspec) in pubspecs.entries) ...[
    if (_pluginSection(pubspec)?.containsKey('implements') ?? false) name,
    for (final platform in _pluginPlatforms(pubspec)?.values ?? const <Object?>[])
      if (platform is YamlMap && platform['default_package'] is String) platform['default_package'] as String,
  ],
};

/// The packages this app's Dart code can reach: everything it depends on,
/// directly or through other packages, without going through a platform
/// implementation package.
Set<String> _reachablePackages(Map<String, YamlMap> pubspecs) {
  final implementations = _platformImplementations(pubspecs);
  final appName = (loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap)['name'] as String;
  final reachable = <String>{};
  final pending = [appName];
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (implementations.contains(name) || !reachable.add(name)) continue;
    final pubspec = pubspecs[name];
    if (pubspec == null) throw StateError('$name is a dependency but pub did not resolve it; run flutter pub get');
    final dependencies = pubspec['dependencies'];
    if (dependencies is YamlMap) pending.addAll(dependencies.keys.cast<String>());
  }
  return reachable;
}

/// The desktop platforms each Flutter plugin this app can reach does not
/// implement.
Map<String, List<String>> _pluginsMissingDesktopPlatforms() {
  final pubspecs = _resolvedPubspecs();
  final missing = <String, List<String>>{};
  for (final name in _reachablePackages(pubspecs)) {
    final pubspec = pubspecs[name]!;
    if (_pluginSection(pubspec) == null) continue;
    final declared = _pluginPlatforms(pubspec)?.keys.toSet() ?? const <Object?>{};
    final absent = _desktopPlatforms.where((platform) => !declared.contains(platform)).toList();
    if (absent.isNotEmpty) missing[name] = absent;
  }
  return missing;
}

void main() {
  test('desktop_app_never_depends_on_the_mobile_app: neither lib/ nor the resolved packages reference it', () {
    final dartFiles = Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(dartFiles, isNotEmpty, reason: 'lib/ has no Dart files; the check would pass vacuously');

    final violations = <String>[
      for (final file in dartFiles)
        for (final match in _directiveUri.allMatches(file.readAsStringSync()))
          if (match.group(1)!.startsWith('package:$_mobileAppPackage/')) '${file.path}: ${match.group(1)}',
    ];

    expect(violations, isEmpty, reason: 'The desktop app imports the mobile app:\n${violations.join('\n')}');
    expect(_resolvedPubspecs().keys, isNot(contains(_mobileAppPackage)));
  });

  test('every_plugin_supports_all_desktop_platforms: no plugin the app can reach lacks macOS, Windows or Linux', () {
    final unexpected = Map.of(_pluginsMissingDesktopPlatforms())
      ..removeWhere((name, _) => _knownUnsupportedPlugins.containsKey(name));

    expect(
      unexpected,
      isEmpty,
      reason:
          'These plugins do not implement every desktop platform (plugin: missing platforms). '
          'Replace them, or put the feature behind an interface in wallet_core.',
    );
  });

  test('the_unsupported_plugin_allowlist_has_no_stale_entries: each entry is reachable and still unsupported', () {
    final stale = _knownUnsupportedPlugins.keys.toSet().difference(_pluginsMissingDesktopPlatforms().keys.toSet());

    expect(stale, isEmpty, reason: 'Remove these from _knownUnsupportedPlugins; they no longer need an exception.');
  });
}
