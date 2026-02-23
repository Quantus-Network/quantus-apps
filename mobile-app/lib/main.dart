import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app_initializer.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:resonance_network_wallet/utils/env_utils.dart';
import 'package:resonance_network_wallet/utils/feature_flags.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';
import 'package:resonance_network_wallet/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable edge-to-edge display
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent, statusBarColor: Colors.transparent),
  );

  await dotenv.load();

  // Initialize Supabase
  await Supabase.initialize(url: EnvUtils.supabaseUrl, anonKey: EnvUtils.supabaseKey);
  await QuantusSdk.init();
  if (FeatureFlags.enableRemoteNotifications) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.getOptionsForEnvironment());
  }

  Telemetrydecksdk.start(
    const TelemetryManagerConfiguration(
      appID: '098B4397-8426-4054-B379-0E4C53D2CA63',
      salt: 'QDay',
      // debug: true,
    ),
  );

  runApp(
    const ProviderScope(
      child: AppInitializer(child: AppLifecycleManager(child: ResonanceWalletApp())),
    ),
  );
}
