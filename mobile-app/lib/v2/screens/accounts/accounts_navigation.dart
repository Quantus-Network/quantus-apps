import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';

/// Route name of the Accounts popup sheet, used to pop back to it.
const accountsSheetRouteName = 'accounts_sheet';

/// Pops back to the already-open Accounts popup sheet. Every in-app
/// add/import/disconnect flow originates from that sheet, so it stays in the
/// navigation stack and we simply pop back to it instead of rebuilding Home.
///
/// When [highlightAccountId] is given, that account is highlighted and scrolled
/// into view once the sheet is revealed.
void returnToAccountsSheet(BuildContext context, WidgetRef ref, {String? highlightAccountId}) {
  if (highlightAccountId != null) {
    ref.read(openAccountsIntentProvider.notifier).state = OpenAccountsIntent(highlightAccountId: highlightAccountId);
  }
  Navigator.of(context).popUntil((route) => route.settings.name == accountsSheetRouteName);
}
