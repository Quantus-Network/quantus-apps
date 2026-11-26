/// Keyset position in an account's `account_event` history, which is paged in
/// `(timestamp desc, id desc)` order. The next page contains rows strictly
/// after this one.
///
/// [timestamp] is the indexer's `timestamptz` string exactly as it was
/// returned, so it round-trips into the next query without any re-formatting.
class AccountEventCursor {
  final String timestamp;
  final String id;

  const AccountEventCursor({required this.timestamp, required this.id});

  /// Where a history read oldest first starts when nothing of it has been
  /// read and it holds nothing yet: every row is strictly after it.
  static const beforeAnyEvent = AccountEventCursor(timestamp: '1970-01-01T00:00:00+00:00', id: '');

  @override
  String toString() => 'AccountEventCursor(timestamp: $timestamp, id: $id)';
}
