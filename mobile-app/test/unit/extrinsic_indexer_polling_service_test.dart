import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/services/extrinsic_indexer_polling_service.dart';

import '../fakes.dart';

void main() {
  test('an extrinsic indexer polling timeout is reported through telemetryProvider', () {
    fakeAsync((async) {
      final telemetry = FakeTelemetry();
      final removed = <String>[];
      final serviceProvider = Provider<ExtrinsicIndexerPollingService<String, int>>(
        (ref) => ExtrinsicIndexerPollingService(
          ref,
          ExtrinsicIndexerPollingConfig(
            logPrefix: '[TestPoller]',
            getId: (pending) => pending,
            getExtrinsicHash: (pending) => '0xhash',
            isStillPending: (ref, id) => !removed.contains(id),
            removePending: (ref, id) => removed.add(id),
            showTimeoutToast: (ref) {},
            confirmIfIndexed: (ref, context, pending) async => false,
          ),
        ),
      );
      final container = ProviderContainer(overrides: testWalletCoreOverrides(telemetry: telemetry));
      final service = container.read(serviceProvider);

      service.startPolling(0, 'tx-1');
      async.elapse(const Duration(minutes: 5, seconds: 10));

      expect(telemetry.events, ['extrinsic_indexer_polling_timeout']);
      expect(removed, ['tx-1']);

      service.dispose();
      container.dispose();
    });
  });
}
