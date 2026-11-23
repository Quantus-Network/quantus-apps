import 'dart:async';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// What saves a send's recipient among the recent addresses once the send has
/// gone out. Taken before the send's asynchronous work, because the widget
/// behind [read] can be gone after it. The saving does nothing when the wallet
/// was reset in between, and a save that fails is logged and does not fail the
/// send, which has already gone out.
void Function(String recipient) recipientRememberer(ProviderReader read) {
  final session = read(walletSessionProvider);
  final ticket = session.ticket;
  final recents = read(recentAddressesServiceProvider);
  return (recipient) {
    if (!session.stillCurrent(ticket, dropping: "saving a send's recipient")) return;
    unawaited(
      recents.addAddress(recipient).catchError((Object e) => quantusPrint('Failed to save recent address: $e')),
    );
  };
}
