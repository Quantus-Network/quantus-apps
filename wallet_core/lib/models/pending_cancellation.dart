class PendingCancellation {
  final String transactionId;
  final DateTime timestamp;

  const PendingCancellation({required this.transactionId, required this.timestamp});

  Map<String, dynamic> toJson() {
    return {'transactionId': transactionId, 'timestamp': timestamp.millisecondsSinceEpoch};
  }

  factory PendingCancellation.fromJson(Map<String, dynamic> json) {
    return PendingCancellation(
      transactionId: json['transactionId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  bool isExpired({required Duration expiration}) {
    return DateTime.now().difference(timestamp) > expiration;
  }
}
