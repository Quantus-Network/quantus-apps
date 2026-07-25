import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app.dart';
import 'package:resonance_network_wallet/app_initializer.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/shared/utils/env_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';

bool _initialized = false;

/// Initializes everything the app needs before [buildApp] can run.
///
/// Safe to call more than once: the heavy, one-shot initializers (Supabase,
/// the Rust SDK, Telemetry) run only on the first invocation. This lets E2E
/// tests reuse the exact production startup path while running several tests in
/// a single app process.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_initialized) return;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await dotenv.load();

  await Supabase.initialize(url: EnvUtils.supabaseUrl, anonKey: EnvUtils.supabaseKey);
  await QuantusSdk.init();

  Telemetrydecksdk.start(
    const TelemetryManagerConfiguration(appID: '098B4397-8426-4054-B379-0E4C53D2CA63', salt: 'QDay'),
  );

  _initialized = true;
}

/// The root widget tree shared by production and tests.
Widget buildApp() {
  return const ProviderScope(
    child: AppInitializer(child: AppLifecycleManager(child: ResonanceWalletApp())),
  );
}
