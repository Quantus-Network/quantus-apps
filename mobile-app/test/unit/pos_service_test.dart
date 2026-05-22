import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/pos_service.dart';

void main() {
  group('PosService', () {
    test('createPaymentRequest embeds canonical dot-decimal wire amount', () {
      final formattingService = NumberFormattingService(localeConfig: LocaleNumberConfig.commaDecimal);
      final service = PosService(formattingService: formattingService);
      final amountPlanck = BigInt.parse('1500000000000');

      final request = service.createPaymentRequest(accountId: 'account123', amountPlanck: amountPlanck);

      expect(request.amount, '1.5');
      expect(request.paymentUrl, contains('amount=1.5'));
      expect(request.paymentUrl, isNot(contains('amount=1%2C5')));
      expect(request.paymentUrl, contains('to=account123'));
      expect(request.refId, isNotEmpty);
    });
  });
}
