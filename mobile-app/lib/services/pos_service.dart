class PosPaymentRequest {
  final String paymentUrl;
  final String refId;
  final String amount;

  const PosPaymentRequest({required this.paymentUrl, required this.refId, required this.amount});
}

class PosService {
  String generateRefId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now.toRadixString(36).toUpperCase();
  }

  String buildPaymentUrl({required String accountId, required String amount, required String refId}) {
    final uri = Uri.https('www.quantus.com', '/pay', {'to': accountId, 'amount': amount, 'ref': refId});
    return uri.toString();
  }

  PosPaymentRequest createPaymentRequest({required String accountId, required String amount}) {
    final refId = generateRefId();
    final url = buildPaymentUrl(accountId: accountId, amount: amount, refId: refId);
    return PosPaymentRequest(paymentUrl: url, refId: refId, amount: amount);
  }
}
