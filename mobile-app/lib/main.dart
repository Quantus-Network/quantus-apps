import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app_initializer.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await QuantusSdk.init();

  runApp(
    const ProviderScope(
      child: AppInitializer(
        child: AppLifecycleManager(child: ResonanceWalletApp()),
      ),
    ),
  );
}

/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return ProviderScope(
///       child: AppInitializer(
///         child: AppLifecycleManager(
///           child: MaterialApp(
///             // Your app content here
///           ),
///         ),
///       ),
///     );
///   }
/// }
