// Different states an asyncronous transaction can be in.

enum TransactionState {
  created,
  ready,
  broadcast,
  inBlock,
  inHistory,
  failed, // For errors
}
