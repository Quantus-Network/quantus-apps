import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/utils/notification_id.dart';

void main() {
  // The same names and ids are checked in the push server's tests: it sends a
  // pushed notification under the id the app shows its own one under, so that
  // the app's replaces it.
  const vectors = {
    '': 18652613,
    'a': 1678518572,
    'received_0001146057-3ef3e-000006': 149514113,
    'incoming_0001215213-e4ed9-000004': 1205035396,
    'send_tx-1': 1288537590,
    // What happens to a proposal is named by its kind and the chain's id of
    // the event, which the indexer keeps its record under.
    'proposal_created_0001443735-f0fbc-000004': 1592488721,
    'proposal_signed_0001443735-f0fbc-000004': 430427913,
    'proposal_ready_0001443735-f0fbc-000005': 1840862533,
    'proposal_executed_0001443735-f0fbc-000004': 1997411692,
    'proposal_cancelled_0001443735-f0fbc-000004': 1461067774,
    'proposal_removed_0001443735-f0fbc-000004': 1384582437,
  };

  test('a notification\'s name gives the id the push server works out for it too', () {
    for (final MapEntry(key: name, value: id) in vectors.entries) {
      expect(notificationSystemId(name), id, reason: '"$name"');
    }
  });

  test('the id fits the 31 bits the notification plugins take, whatever the name', () {
    for (final name in ['proposal_executed_0001443735-f0fbc-000004', 'send_${'x' * 500}', 'diterima_é漢字']) {
      expect(notificationSystemId(name), inInclusiveRange(0, 0x7fffffff), reason: name);
    }
  });
}
