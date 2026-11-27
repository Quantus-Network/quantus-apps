import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The entitlements file's keys, each with its value: `true`, `false`, or the
/// text of a `<string>`.
Map<String, Object> _plist(String path) {
  final text = File(path).readAsStringSync();
  final entries = RegExp(r'<key>([^<]+)</key>\s*(?:<(true|false)/>|<string>([^<]*)</string>)').allMatches(text);
  return {for (final m in entries) m[1]!: m[2] != null ? m[2] == 'true' : m[3]!};
}

const _sandbox = 'com.apple.security.app-sandbox';
const _networkClient = 'com.apple.security.network.client';
const _camera = 'com.apple.security.device.camera';
const _jit = 'com.apple.security.cs.allow-jit';
const _networkServer = 'com.apple.security.network.server';
const _push = 'com.apple.developer.aps-environment';

const _team = '8BRRAHLVW5';

/// The app target's build configurations (Debug, Profile, Release), each as
/// the text of its build settings.
Map<String, String> _appConfigurations() {
  final project = File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final blocks = RegExp(r'isa = XCBuildConfiguration;(.*?)name = (\w+);', dotAll: true).allMatches(project);
  return {
    for (final block in blocks)
      if (block[1]!.contains('INFOPLIST_FILE = Runner/Info.plist')) block[2]!: block[1]!,
  };
}

void main() {
  // The Mac App Store takes only sandboxed apps. Debug is sandboxed too, so
  // that every `flutter run` meets the same limits a TestFlight build does.
  group('macOS entitlements', () {
    final release = _plist('macos/Runner/Release.entitlements');
    final debug = _plist('macos/Runner/DebugProfile.entitlements');

    test('Release turns the App Sandbox on', () {
      expect(release[_sandbox], isTrue);
    });

    test('Debug turns the App Sandbox on', () {
      expect(debug[_sandbox], isTrue);
    });

    // A Release build is signed by Xcode for the team, which can only grant
    // push the app asks for here; the App Store export turns `development`
    // into `production`.
    test('Release asks for the network, the camera and push', () {
      expect(release, {_sandbox: true, _networkClient: true, _camera: true, _push: 'development'});
    });

    // Flutter's debugger needs JIT and a local server; a release build needs
    // neither. Push needs a provisioning profile, which an unsigned debug or
    // CI build does not have: asking for it, the app would not launch.
    test('Debug adds only JIT and the local server to Release, without push', () {
      expect(debug, {...release, _jit: true, _networkServer: true}..remove(_push));
    });
  });

  // As the phone's Runner: Xcode signs a Release build for the team with the
  // Apple account it is signed into, and picks or makes the certificates and
  // profiles. Debug and Profile need no account, for `flutter run` and CI.
  group('macOS signing', () {
    final configurations = _appConfigurations();

    test('Release is signed automatically by team $_team', () {
      final release = configurations['Release']!;
      expect(release, contains('DEVELOPMENT_TEAM = $_team;'));
      expect(release, contains('CODE_SIGN_STYLE = Automatic;'));
      expect(release, contains('CODE_SIGN_IDENTITY = "Apple Development";'));
    });

    test('Debug and Profile are not tied to a team', () {
      expect(configurations.keys, containsAll(['Debug', 'Profile']));
      for (final name in ['Debug', 'Profile']) {
        expect(configurations[name], isNot(contains('DEVELOPMENT_TEAM')), reason: name);
      }
    });

    // upload_macos_build.sh exports the package; Transporter uploads it.
    test('ExportOptions.plist exports for App Store Connect', () {
      expect(_plist('macos/ExportOptions.plist'), {
        'method': 'app-store-connect',
        'destination': 'export',
        'teamID': _team,
        'signingStyle': 'automatic',
      });
    });
  });

  group('macOS Info.plist', () {
    final info = _plist('macos/Runner/Info.plist');

    test('names the Finance category', () {
      expect(info['LSApplicationCategoryType'], 'public.app-category.finance');
    });

    // Only exempt encryption: HTTPS and signing transactions. App Store
    // Connect then asks no export question for each build.
    test('answers the encryption question', () {
      expect(info['ITSAppUsesNonExemptEncryption'], isFalse);
    });
  });

  test('the copyright names Quantus Labs', () {
    final config = File('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync();
    final copyright = RegExp(r'^PRODUCT_COPYRIGHT = (.*)$', multiLine: true).firstMatch(config)![1]!;
    expect(copyright, 'Copyright © 2026 Quantus Labs. All rights reserved.');
  });
}
