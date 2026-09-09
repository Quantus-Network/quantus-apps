import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/exchange_rates_result.dart';

// Quersi service singleton
class QuersiService {
  final _remoteConfigsEndpoint = Uri.parse('${AppConstants.quersiEndpoint}/configs/wallet');
  final _exchangeRatesEndpoint = Uri.parse('${AppConstants.quersiEndpoint}/exchange-rates');

  static final QuersiService _instance = QuersiService._internal();
  factory QuersiService() => _instance;
  QuersiService._internal();

  Future<RemoteConfigModel> getRemoteConfig() async {
    final http.Response response = await http.get(
      _remoteConfigsEndpoint,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Configs request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final Map<String, dynamic>? responseBody = jsonDecode(response.body);
    final Map<String, dynamic>? data = responseBody?['data'];

    if (data == null) {
      throw Exception('Configs request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    return RemoteConfigModel.fromJson(data);
  }

  Future<ExchangeRatesResult> getExchangeRates() async {
    final http.Response response = await http.get(
      _exchangeRatesEndpoint,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Exchange rates request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final Map<String, dynamic>? responseBody = jsonDecode(response.body);
    final Map<String, dynamic>? data = responseBody?['data'];

    if (data == null) {
      throw Exception('Exchange rates not found!');
    }

    return ExchangeRatesResult.fromJson(data);
  }
}
