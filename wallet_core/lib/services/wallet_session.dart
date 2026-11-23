import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wallet this device holds, from one reset to the next. Asynchronous work
/// takes a [ticket] before it waits and asks [isCurrent] after: what answers
/// for a wallet since wiped must not reach the next one.
class WalletSession {
  int _ticket = 0;
  bool _resetting = false;

  int get ticket => _ticket;

  /// False for the whole of a reset, whenever the ticket was taken: a poll
  /// that starts during the wipe must not write into it either.
  bool isCurrent(int ticket) => !_resetting && ticket == _ticket;

  void beginReset() => _resetting = true;

  /// The wipe failed and the wallet is still here: its tickets hold again.
  void cancelReset() => _resetting = false;

  /// The wallet is gone: every ticket taken so far has lapsed.
  void finishReset() {
    _ticket++;
    _resetting = false;
  }
}

final walletSessionProvider = Provider<WalletSession>((ref) => WalletSession());
