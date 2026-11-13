import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app.dart';
import 'package:resonance_network_wallet/app_initializer.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/firebase_options.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';

bool _initialized = false;

/// Initializes everything the app needs before [buildApp] can run.
///
/// Safe to call more than once: the heavy, one-shot initializers (the Rust
/// SDK, Telemetry) run only on the first invocation. This lets E2E tests reuse
/// the exact production startup path while running several tests in a single
/// app process.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_initialized) return;
  if (AppConstants.swapPreflight && !kDebugMode) throw StateError('SWAP_PREFLIGHT_ASSET is for debug builds only');
  if (AppConstants.swapPreflight && AppConstants.swapPreflightAddress.isEmpty) {
    throw StateError('SWAP_PREFLIGHT_ASSET needs SWAP_PREFLIGHT_ADDRESS');
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.getOptionsForEnvironment());

  // Unusable offline, so recover the online state fast.
  ConnectivityService.instanceRetryInterval = const Duration(seconds: 3);
  await QuantusSdk.init();

  Telemetrydecksdk.start(
    const TelemetryManagerConfiguration(appID: '098B4397-8426-4054-B379-0E4C53D2CA63', salt: 'QDay'),
  );

  _initialized = true;
}

/// The mobile implementations of wallet_core's platform seams.
List<Override> mobileWalletCoreOverrides() => walletCoreOverrides(
  telemetry: (_) => TelemetryService(),
  pushRegistration: (ref) => ref.watch(firebaseMessagingServiceProvider),
  localNotifications: (ref) => ref.watch(localNotificationsServiceProvider),
);

/// The root widget tree shared by production and tests.
Widget buildApp() {
  return ProviderScope(
    overrides: mobileWalletCoreOverrides(),
    child: const AppInitializer(child: AppLifecycleManager(child: ResonanceWalletApp())),
  );
}
