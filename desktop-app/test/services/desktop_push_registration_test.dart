import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/desktop_push_registration.dart';

void main() {
  test('desktop push registration completes every call without doing anything', () async {
    const pushRegistration = DesktopPushRegistration();

    await expectLater(pushRegistration.registerDevice(), completes);
    await expectLater(pushRegistration.registerAddress('qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda'), completes);
    await expectLater(pushRegistration.unregister(), completes);
  });
}
