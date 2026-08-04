import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';

/// Route name of the Accounts screen, used to pop back to it.
const accountsScreenRouteName = 'accounts_screen';

/// Pops back to the already-open Accounts screen. Every in-app
/// add/import/disconnect flow originates from that screen, so it stays in the
/// navigation stack and we simply pop back to it instead of rebuilding Home.
///
/// When [highlightAccountId] is given, that account is highlighted and scrolled
/// into view once the screen is revealed.
void returnToAccountsScreen(BuildContext context, WidgetRef ref, {String? highlightAccountId}) {
  if (highlightAccountId != null) {
    ref.read(openAccountsIntentProvider.notifier).state = OpenAccountsIntent(highlightAccountId: highlightAccountId);
  }
  Navigator.of(context).popUntil((route) => route.settings.name == accountsScreenRouteName);
}
