import 'package:quantus_sdk/quantus_sdk.dart';

/// Helpers for putting the app into a known, clean state between E2E tests.
///
/// Patrol's `clearAppData()` is Android-only, so on a physical iOS device we
/// reset state in-process by wiping the same storage the app uses
/// (`SharedPreferences` + secure storage) via [SettingsService.clearAll].
class AppState {
  AppState._();

  /// Wipes all persisted wallet state so the next launch starts at onboarding.
  ///
  /// [SettingsService] must already be initialized (done by `bootstrap()` via
  /// `QuantusSdk.init()`), so always call this after bootstrapping the app.
  static Future<void> reset() async {
    await SettingsService().clearAll();
  }
}
