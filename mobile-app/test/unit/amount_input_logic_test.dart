import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/services/exchange_rate_service.dart';
import 'package:resonance_network_wallet/shared/utils/amount_input_logic.dart';

void main() {
  group('AmountInputLogic', () {
    late ExchangeRateService exchangeRateService;
    late LocaleNumberConfig localeConfig;
    late NumberFormattingService formattingService;

    setUp(() {
      exchangeRateService = ExchangeRateService(rates: {'USD': Decimal.one});
      localeConfig = LocaleNumberConfig.dotDecimal;
      formattingService = NumberFormattingService(localeConfig: localeConfig);
    });

    AmountInputLogic createLogic({FiatCurrency? selectedFiat}) {
      return AmountInputLogic(
        exchangeRateService: exchangeRateService,
        selectedFiat: selectedFiat ?? FiatCurrency.usd,
        localeConfig: localeConfig,
        formattingService: formattingService,
      );
    }

    test('quanToFiatString converts correctly', () {
      final logic = createLogic();
      final amount = BigInt.from(1000000000000); // 1.0 QUAN
      expect(logic.quanToFiatString(amount), '1.00');
    });

    test('fiatStringToQuan parses correctly', () {
      final logic = createLogic();
      final result = logic.fiatStringToQuan('1.00');
      expect(result, BigInt.from(1000000000000));
    });

    test('getToggledInput handles QUAN -> Fiat toggle', () {
      final logic = createLogic();
      final amount = BigInt.from(1500000000000); // 1.5 QUAN
      final result = logic.getToggledInput(wasFlipped: false, currentAmount: amount);

      expect(result.text, '1.50');
      expect(result.amount, BigInt.from(1500000000000));
    });

    test('getToggledInput handles Fiat -> QUAN toggle', () {
      final logic = createLogic();
      final amount = BigInt.from(1500000000000); // 1.5 QUAN
      final result = logic.getToggledInput(wasFlipped: true, currentAmount: amount);

      expect(result.text, '1.5');
      expect(result.amount, amount);
    });

    test('onAmountChanged handles QUAN input', () {
      final logic = createLogic();
      final result = logic.onAmountChanged(value: '1.5', isFlipped: false);
      expect(result, BigInt.from(1500000000000));
    });

    test('onAmountChanged handles Fiat input', () {
      final logic = createLogic();
      final result = logic.onAmountChanged(value: '1.50', isFlipped: true);
      expect(result, BigInt.from(1500000000000));
    });

    test('quanToFiatString returns empty string for zero', () {
      final logic = createLogic();
      expect(logic.quanToFiatString(BigInt.zero), '');
    });

    test('formatQuanAmount returns empty string for zero', () {
      final logic = createLogic();
      expect(logic.formatQuanAmount(BigInt.zero), '');
    });
  });
}
