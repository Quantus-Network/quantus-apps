// Checks a login password through the system's real PAM, which the tests
// under test/ only imitate. It needs Linux, the app's PAM service installed
// (see the README) and the password of the user running it:
//
//   QUANTUS_PAM_TEST_PASSWORD=... flutter test tool/pam_login_password_test.dart
//
// CI runs it on its Linux runner, whose throwaway user is given a password
// for it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';

void main() {
  const loginPassword = PamLoginPassword();
  late String password;

  setUpAll(() {
    if (!Platform.isLinux) fail('This checks the real PAM, which only Linux has.');
    password =
        Platform.environment['QUANTUS_PAM_TEST_PASSWORD'] ??
        fail('Set QUANTUS_PAM_TEST_PASSWORD to the login password of the user running this.');
  });

  test('the app\'s PAM service is installed', () async {
    expect(await loginPassword.isSetUp(), isTrue);
  });

  test('the login password of the user running this is accepted', () async {
    final messages = <String>[];

    final result = await loginPassword.check(password, onMessage: messages.add);

    expect(result, LoginPasswordResult.accepted, reason: 'PAM said: $messages');
  });

  test('a wrong password is refused', () async {
    final messages = <String>[];

    final result = await loginPassword.check('not-$password', onMessage: messages.add);

    expect(result, LoginPasswordResult.refused, reason: 'PAM said: $messages');
  });
}
