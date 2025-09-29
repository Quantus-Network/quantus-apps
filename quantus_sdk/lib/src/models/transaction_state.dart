// Different states an asyncronous transaction can be in.

enum TransactionState {
  created,
  ready,
  pending,
  inBlock,
  inHistory,
  failed, // For errors
}
