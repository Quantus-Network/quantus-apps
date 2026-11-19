import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../fakes.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

void main() {
  group("the Transaction panel's width", () {
    ({ProviderContainer container, FakeSettingsService settings, _RecordingTelemetry telemetry}) open({String? saved}) {
      final settings = FakeSettingsService();
      if (saved != null) settings.strings[InspectorWidthNotifier.settingsKey] = saved;
      final telemetry = _RecordingTelemetry();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(settings),
          telemetryProvider.overrideWithValue(telemetry),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, settings: settings, telemetry: telemetry);
    }

    test('starts 380 wide and keeps within 360 and 480', () {
      final (:container, settings: _, telemetry: _) = open();
      final width = container.read(inspectorWidthProvider.notifier);

      expect(container.read(inspectorWidthProvider), 380);
      width.resizeTo(500);
      expect(container.read(inspectorWidthProvider), 480);
      width.resizeTo(300);
      expect(container.read(inspectorWidthProvider), 360);
    });

    test('is kept for the next start', () async {
      final (:container, :settings, telemetry: _) = open();

      container.read(inspectorWidthProvider.notifier).resizeTo(420);
      await container.read(inspectorWidthProvider.notifier).save();

      expect(settings.strings[InspectorWidthNotifier.settingsKey], '420.0');
      expect(open(saved: '420.0').container.read(inspectorWidthProvider), 420);
      expect(open(saved: '900').container.read(inspectorWidthProvider), 480);
    });

    test('saved unreadable, it starts at 380 and the stray value is reported', () {
      final (:container, settings: _, :telemetry) = open(saved: 'wide');

      expect(container.read(inspectorWidthProvider), 380);
      expect(telemetry.errors, ['The saved transaction panel width is unreadable']);
    });
  });
}
