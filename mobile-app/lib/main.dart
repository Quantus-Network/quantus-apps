import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app_initializer.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await QuantusSdk.init();
  Telemetrydecksdk.start(
    const TelemetryManagerConfiguration(
      appID: '098B4397-8426-4054-B379-0E4C53D2CA63',
      salt: 'QDay',
      // debug: true,
    ),
  );

  runApp(
    const ProviderScope(
      child: AppInitializer(
        child: AppLifecycleManager(child: ResonanceWalletApp()),
      ),
    ),
  );
}
