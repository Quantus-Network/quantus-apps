import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wallet this device holds, from one reset to the next. Asynchronous work
/// takes a [ticket] before it waits and asks [isCurrent] after: what answers
/// for a wallet since wiped must not reach the next one.
class WalletSession {
  int _ticket = 0;

  int get ticket => _ticket;

  bool isCurrent(int ticket) => ticket == _ticket;

  /// The wallet is gone: every ticket taken so far has lapsed.
  void finishReset() => _ticket++;
}

final walletSessionProvider = Provider<WalletSession>((ref) => WalletSession());
