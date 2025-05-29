import 'package:resonance_network_wallet/core/models/transaction_status.dart';
import 'package:resonance_network_wallet/core/models/transaction_type.dart';

class Transaction {
  final String id;
  final BigInt amount;
  final DateTime timestamp;
  final TransactionType type;
  final String otherParty;
  final TransactionStatus status;

  Transaction({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.otherParty,
    required this.status,
  });
}
