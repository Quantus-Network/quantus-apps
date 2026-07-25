import 'package:patrol/patrol.dart';
import 'package:resonance_network_wallet/bootstrap/app_bootstrap.dart';

import 'app_state.dart';
import 'patrol_timeouts.dart';
import 'selectors.dart';

/// Launches the real app in a guaranteed-clean state for an E2E test.
///
/// This runs the production [bootstrap] (dotenv, Supabase, SDK, telemetry),
/// then wipes all persisted wallet state via [AppState.reset] so the app starts
/// at onboarding, and finally pumps the real widget tree.
///
/// We use [PatrolIntegrationTester.pumpWidget] (no settle) on purpose: the
/// onboarding/home screens show looping progress indicators while loading, and
/// `pumpAndSettle` would time out waiting for them to stop. We instead wait for
/// a specific screen to become visible.
class AppLauncher {
  AppLauncher._();

  /// Boots the app onto a fresh Welcome (onboarding) screen.
  static Future<void> launchFresh(PatrolIntegrationTester $) async {
    await bootstrap();
    await AppState.reset();

    await $.pumpWidget(buildApp());

    await $(Selectors.welcomeScreen).waitUntilVisible(timeout: PatrolTimeouts.appLaunch);
  }
}
