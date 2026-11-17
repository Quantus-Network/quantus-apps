@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_library.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_session.dart';
import 'package:quantus_desktop_wallet/services/pam/posix_user.dart';

import 'pam/fake_pam_library.dart';

// The check runs in an isolate of its own, which gets its libpam by calling
// one of these: a system whose login accepts the password 'right'.

PamLibrary _pamAcceptingRight() => FakePamLibrary(
  onAuthenticate: (pam) {
    pam.converse([(PamStyle.textInfo, 'Place your finger on the fingerprint reader')]);
    final (_, answers) = pam.converse([(PamStyle.promptEchoOff, 'Password: ')]);
    return answers.single == 'right' ? PamCode.success : PamCode.authError;
  },
);

PamLibrary _pamAskingForACode() => FakePamLibrary(
  onAuthenticate: (pam) {
    pam.converse([(PamStyle.promptEchoOff, 'Password: ')]);
    final (code, _) = pam.converse([(PamStyle.promptEchoOn, 'One-time code: ')]);
    return code;
  },
);

PamLibrary _pamOutOfService() => FakePamLibrary(onAuthenticate: (_) => PamCode.authInfoUnavailable);

PamLibrary _pamMissing() => throw ArgumentError('Failed to load dynamic library libpam.so.0');

/// A libpam that accepts the password only for the user the app must name.
PamLibrary _pamForAlexOnly() => FakePamLibrary(
  onAuthenticate: (pam) {
    pam.converse([(PamStyle.promptEchoOff, 'Password: ')]);
    return pam.user == 'alex' && pam.service == 'quantus-wallet' ? PamCode.success : PamCode.authError;
  },
);

String _alex() => 'alex';

void main() {
  group('isSetUp', () {
    late Directory first;
    late Directory second;

    setUp(() {
      first = Directory.systemTemp.createTempSync('pam-first');
      second = Directory.systemTemp.createTempSync('pam-second');
      addTearDown(() {
        first.deleteSync(recursive: true);
        second.deleteSync(recursive: true);
      });
    });

    PamLoginPassword loginPassword({PamLibrary Function() openLibrary = _pamAcceptingRight}) =>
        PamLoginPassword(openLibrary: openLibrary, currentUser: _alex, serviceDirectories: [first.path, second.path]);

    test('is not set up when no directory holds the app\'s PAM service', () async {
      File('${first.path}/login').createSync();

      expect(await loginPassword().isSetUp(), isFalse);
    });

    for (final (name, index) in [('first', 0), ('second', 1)]) {
      test('is set up when the $name directory holds the app\'s PAM service', () async {
        File('${[first, second][index].path}/quantus-wallet').createSync();

        expect(await loginPassword().isSetUp(), isTrue);
      });
    }

    test('a system with no libpam is an error, not "not set up"', () async {
      File('${first.path}/quantus-wallet').createSync();

      await expectLater(loginPassword(openLibrary: _pamMissing).isSetUp(), throwsArgumentError);
    });

    test('looks where every libpam looks, unless told otherwise', () {
      expect(const PamLoginPassword().serviceDirectories, ['/etc/pam.d', '/usr/lib/pam.d']);
    });
  });

  group('check', () {
    PamLoginPassword loginPassword(PamLibrary Function() openLibrary) =>
        PamLoginPassword(openLibrary: openLibrary, currentUser: _alex);

    test('accepts the right password, passing on what the system says meanwhile', () async {
      final messages = <String>[];

      final result = await loginPassword(_pamAcceptingRight).check('right', onMessage: messages.add);

      expect(result, LoginPasswordResult.accepted);
      expect(messages, ['Place your finger on the fingerprint reader']);
    });

    test('refuses a wrong password', () async {
      expect(await loginPassword(_pamAcceptingRight).check('wrong', onMessage: (_) {}), LoginPasswordResult.refused);
    });

    test('checks the app\'s own PAM service, for the user the app runs as', () async {
      expect(await loginPassword(_pamForAlexOnly).check('any', onMessage: (_) {}), LoginPasswordResult.accepted);
    });

    test('a login that asks for more than a password is that error', () async {
      await expectLater(
        loginPassword(_pamAskingForACode).check('right', onMessage: (_) {}),
        throwsA(isA<PamUnexpectedPromptException>().having((e) => e.prompt, 'prompt', 'One-time code: ')),
      );
    });

    test('a PAM failure is not hidden', () async {
      await expectLater(
        loginPassword(_pamOutOfService).check('right', onMessage: (_) {}),
        throwsA(isA<PamException>().having((e) => e.code, 'code', PamCode.authInfoUnavailable)),
      );
    });

    test('a system with no libpam is an error, and the check does not hang', () async {
      await expectLater(
        loginPassword(_pamMissing).check('right', onMessage: (_) {}).timeout(const Duration(seconds: 10)),
        throwsArgumentError,
      );
    });
  });

  group('currentUserName', () {
    test('names the user the tests run as', () {
      expect(currentUserName(), (Process.runSync('id', ['-un']).stdout as String).trim());
    });
  });
}
