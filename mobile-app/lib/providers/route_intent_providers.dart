import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final transactionIntentProvider = StateProvider<TransactionEvent?>((_) => null);
final sharedAccountIntentProvider = StateProvider<String?>((_) => null);

class PaymentIntent {
  final String to;
  final String amount;
  final String? ref;

  const PaymentIntent({required this.to, required this.amount, this.ref});
}

final paymentIntentProvider = StateProvider<PaymentIntent?>((_) => null);
