import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/services/pos_service.dart';

void main() {
  group('PosService', () {
    test('createPaymentRequest embeds raw planck integer amount', () {
      final service = PosService();
      final amountPlanck = BigInt.parse('1500000000000');

      final request = service.createPaymentRequest(accountId: 'account123', amountPlanck: amountPlanck);

      expect(request.paymentUrl, contains('amount=1500000000000'));
      expect(request.paymentUrl, contains('to=account123'));
      expect(request.refId, isNotEmpty);
    });
  });
}
