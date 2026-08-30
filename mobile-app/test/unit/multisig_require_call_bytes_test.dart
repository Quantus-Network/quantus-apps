import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';

void main() {
  group('requireCallBytes', () {
    test('returns the bytes the sheet loaded', () {
      const bytes = [1, 2, 3];
      expect(requireCallBytes(bytes, 'Execute'), bytes);
    });

    // Approve and execute are both refused by the chain unless they carry the
    // stored call, so a sheet that reached the builder without it must fail
    // loudly rather than submit something the chain will reject.
    test('names the action when the bytes never loaded', () {
      expect(
        () => requireCallBytes(null, 'Execute'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Execute'))),
      );
    });
  });
}
