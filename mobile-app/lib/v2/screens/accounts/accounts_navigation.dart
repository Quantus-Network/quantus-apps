import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_screen.dart';

/// Route name of the Accounts screen, used to pop back to it.
const accountsScreenRouteName = 'accounts_screen';

Future<T?> openAccountsScreen<T>(BuildContext context, {String? highlightAccountId}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      settings: const RouteSettings(name: accountsScreenRouteName),
      builder: (_) => AccountsScreen(highlightAccountId: highlightAccountId),
    ),
  );
}

/// Returns to the Accounts screen after an add/import/disconnect flow.
///
/// Pops back to the already-open Accounts screen when the flow started there.
/// Flows started elsewhere (e.g. Settings → Add account) have no Accounts route
/// in the stack, so we pop to the root and push a fresh Accounts screen instead
/// of popping the whole stack.
///
/// When [highlightAccountId] is given, that account is highlighted and scrolled
/// into view once the screen is shown.
void returnToAccountsScreen(BuildContext context, WidgetRef ref, {String? highlightAccountId}) {
  var foundAccountsRoute = false;
  Navigator.of(context).popUntil((route) {
    foundAccountsRoute = route.settings.name == accountsScreenRouteName;
    return foundAccountsRoute || route.isFirst;
  });

  if (!foundAccountsRoute) {
    openAccountsScreen(context, highlightAccountId: highlightAccountId);
  } else if (highlightAccountId != null) {
    ref.read(openAccountsIntentProvider.notifier).state = OpenAccountsIntent(highlightAccountId: highlightAccountId);
  }
}
