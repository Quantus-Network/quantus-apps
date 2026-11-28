import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Starts this launch's analytics session as the app starts, and reports
/// each sheet as it opens, as the phone reports its screens.
final telemetryStartupProvider = Provider<void>((ref) {
  final telemetry = ref.watch(telemetryProvider);
  ref.listen(shellSheetProvider, (_, sheet) {
    if (sheet != null) telemetry.sendEvent('screen_view', parameters: {'screen': sheet.telemetryName});
  });
});
