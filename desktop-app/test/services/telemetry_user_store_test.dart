import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/telemetry_user_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('telemetry_user_store_test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => folder.delete(recursive: true));

  FileTelemetryUserStore store() => FileTelemetryUserStore(directory: () async => folder);

  test('makes a random user ID once, in a file of its own in the app support folder', () async {
    final id = await store().userId();

    expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    final file = File('${folder.path}/telemetry_user.json');
    expect(jsonDecode(await file.readAsString()), {'userId': id});
  });

  test('gives the same user ID on every later launch', () async {
    final id = await store().userId();

    expect(await store().userId(), id);
    expect(await store().userId(), id);
  });

  test('keeps the user ID through a wallet reset, which clears the wallet\'s preferences', () async {
    final id = await store().userId();
    final prefs = await SharedPreferences.getInstance();
    // Nothing of it is in the preferences a reset clears.
    expect(prefs.getKeys(), isEmpty);

    await prefs.clear();

    expect(await store().userId(), id);
  });

  test('another computer, or another folder, is another user', () async {
    final other = await Directory.systemTemp.createTemp('telemetry_user_store_test_other');
    addTearDown(() => other.delete(recursive: true));

    expect(await FileTelemetryUserStore(directory: () async => other).userId(), isNot(await store().userId()));
  });
}
