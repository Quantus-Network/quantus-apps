enum TransactionFilter { all, send, receive }

extension TransactionFilterDisplayName on TransactionFilter {
  String get displayName {
    switch (this) {
      case TransactionFilter.all:
        return 'All';
      case TransactionFilter.send:
        return 'Send';
      case TransactionFilter.receive:
        return 'Receive';
    }
  }
}
