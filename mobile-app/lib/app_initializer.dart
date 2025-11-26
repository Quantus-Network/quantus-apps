import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';

/// Widget that initializes the polling services for the entire app.
/// This should be placed high in the widget tree, typically in your main app
/// widget.
class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final notificationService = ref.read(localNotificationsServiceProvider);
      await notificationService.init();

      ref.read(historyPollingManagerProvider);
    } catch (e, stackTrace) {
      debugPrint('Initialization error: $e\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
