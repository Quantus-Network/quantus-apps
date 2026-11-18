import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

/// Settings that hold plain text in memory, and can refuse to store it.
class _TextSettings extends FakeSettingsService {
  final strings = <String, String>{};

  /// Why every [setString] fails, when set.
  Object? writeError;

  @override
  String? getString(String key) => strings[key];

  @override
  Future<void> setString(String key, String value) async {
    if (writeError case final error?) throw error;
    strings[key] = value;
  }
}

/// The exchange rates service answering with [rates], to be refreshed in an
/// hour.
http.Client _ratesServer(Map<String, num> rates) => MockClient((request) async {
  final nextUpdate = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return http.Response(
    jsonEncode({
      'data': {'conversion_rates': rates, 'time_next_update_unix': nextUpdate},
    }),
    200,
  );
});

Future<Map<String, Decimal>> _fetchRates(_TextSettings settings, Map<String, num> served) {
  final container = ProviderContainer(overrides: [settingsServiceProvider.overrideWithValue(settings)]);
  addTearDown(container.dispose);
  return http.runWithClient(() => container.read(exchangeRatesProvider.future), () => _ratesServer(served));
}

void main() {
  test('rates just fetched are used and kept for the next start', () async {
    final settings = _TextSettings();

    final rates = await _fetchRates(settings, {'USD': 1, 'IDR': 16000.5});

    expect(rates, {'USD': Decimal.one, 'IDR': Decimal.parse('16000.5')});
    expect(settings.strings, hasLength(1));
  });

  test('rates just fetched are used even when they cannot be kept', () async {
    final settings = _TextSettings()..writeError = Exception('Could not save the rates');

    final rates = await _fetchRates(settings, {'USD': 1, 'IDR': 16000.5});

    expect(rates, {'USD': Decimal.one, 'IDR': Decimal.parse('16000.5')});
    expect(settings.strings, isEmpty);
  });
}
