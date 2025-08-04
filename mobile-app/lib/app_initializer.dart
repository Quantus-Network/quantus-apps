import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';

/// Widget that initializes the polling services for the entire app.
/// This should be placed high in the widget tree, typically in your main app
/// widget.
class AppInitializer extends ConsumerWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the history polling manager
    // This ensures both global polling and transaction tracking are set up
    ref.watch(historyPollingManagerProvider);

    return child;
  }
}
