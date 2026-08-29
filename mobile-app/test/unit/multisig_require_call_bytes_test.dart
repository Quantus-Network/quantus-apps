import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';

void main() {
  group('requireCallBytes', () {
    test('returns the stored call bytes unchanged', () {
      const bytes = [0x02, 0x00, 0x07];
      expect(requireCallBytes(bytes, 'Execute'), same(bytes));
    });

    test('throws rather than build an action without the call it must resubmit', () {
      // Approve and execute are both bound to the proposal's exact bytes, so a
      // missing load must fail loudly instead of submitting a call the chain rejects.
      expect(() => requireCallBytes(null, 'Execute'), throwsA(isA<StateError>()));
      expect(() => requireCallBytes(null, 'Approve'), throwsA(isA<StateError>()));
    });

    test('names the action in the error', () {
      expect(
        () => requireCallBytes(null, 'Execute'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Execute'))),
      );
    });
  });
}
