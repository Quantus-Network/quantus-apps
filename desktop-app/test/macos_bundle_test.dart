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

    // Push, the team and keychain groups are added when a build is signed:
    // in these files they would need a provisioning profile, and an unsigned
    // or CI build would no longer launch.
    test('Release asks only for the network and the camera', () {
      expect(release, {_sandbox: true, _networkClient: true, _camera: true});
    });

    // Flutter's debugger needs JIT and a local server; a release build needs
    // neither.
    test('Debug adds only JIT and the local server to Release', () {
      expect(debug, {...release, _jit: true, _networkServer: true});
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
