import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/app.dart';
import 'package:quantus_desktop_wallet/services/desktop_local_notifications.dart';
import 'package:quantus_desktop_wallet/services/desktop_push_registration.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';

/// Initializes everything the app needs before [buildApp] can run.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuantusSdk.init();
}

/// The desktop implementations of wallet_core's platform seams.
List<Override> desktopWalletCoreOverrides() => walletCoreOverrides(
  telemetry: (_) => const DesktopTelemetry(),
  pushRegistration: (_) => const DesktopPushRegistration(),
  localNotifications: (_) => const DesktopLocalNotifications(),
);

/// The root widget tree shared by production and tests.
Widget buildApp() {
  return ProviderScope(overrides: desktopWalletCoreOverrides(), child: const QuantusDesktopApp());
}
