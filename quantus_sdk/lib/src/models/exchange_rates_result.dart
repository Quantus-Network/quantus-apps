class ExchangeRatesResult {
  final Map<String, double> rates;
  final int timeNextUpdateUnix;

  const ExchangeRatesResult({required this.rates, required this.timeNextUpdateUnix});

  factory ExchangeRatesResult.fromJson(Map<String, dynamic> json) {
    final conversionRates = json['conversion_rates'] as Map<String, dynamic>;
    return ExchangeRatesResult(
      rates: conversionRates.map((k, v) => MapEntry(k, (v as num).toDouble())),
      timeNextUpdateUnix: json['time_next_update_unix'] as int,
    );
  }
}
