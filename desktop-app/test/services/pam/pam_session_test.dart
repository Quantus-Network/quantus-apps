import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_library.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_session.dart';

import 'fake_pam_library.dart';

const _passwordPrompt = (PamStyle.promptEchoOff, 'Password: ');

/// Checks 'the password' for alex with [pam], collecting what PAM says.
PamVerdict _check(FakePamLibrary pam, {List<String>? messages}) => checkPasswordWithPam(
  pam,
  service: 'quantus-wallet',
  user: 'alex',
  password: 'the password',
  onMessage: (message) => messages?.add(message),
);

/// Matches what a conversation came to: the app's return code and its answers.
/// A record's own equality compares the lists by identity.
Matcher _conversed(int code, List<String?> answers) => isA<(int, List<String?>)>()
    .having((conversation) => conversation.$1, 'code', code)
    .having((conversation) => conversation.$2, 'answers', answers);

void main() {
  test('answers the password prompt with the password, and accepts when PAM succeeds', () {
    late (int, List<String?>) conversation;
    final pam = FakePamLibrary(
      onAuthenticate: (pam) {
        conversation = pam.converse([_passwordPrompt]);
        return PamCode.success;
      },
    );

    expect(_check(pam), PamVerdict.accepted);

    expect(conversation, _conversed(PamCode.success, ['the password']));
    expect(pam.service, 'quantus-wallet');
    expect(pam.user, 'alex');
    expect(pam.flags, PamFlag.disallowNullAuthtok);
    expect(pam.authentications, 1);
    expect(pam.ended, [PamCode.success]);
  });

  for (final code in [PamCode.authError, PamCode.maxTries, PamCode.permissionDenied]) {
    test('PAM code $code is a refused password', () {
      final pam = FakePamLibrary(
        onAuthenticate: (pam) {
          pam.converse([_passwordPrompt]);
          return code;
        },
      );

      expect(_check(pam), PamVerdict.refused);
      expect(pam.ended, [code]);
    });
  }

  test('passes on what PAM says, in order, and answers those messages with nothing', () {
    final conversations = <(int, List<String?>)>[];
    final pam = FakePamLibrary(
      onAuthenticate: (pam) {
        conversations.add(pam.converse([(PamStyle.textInfo, 'Place your finger on the fingerprint reader')]));
        conversations.add(pam.converse([(PamStyle.errorMessage, 'Failed to match fingerprint'), _passwordPrompt]));
        return PamCode.success;
      },
    );
    final messages = <String>[];

    expect(_check(pam, messages: messages), PamVerdict.accepted);

    expect(messages, ['Place your finger on the fingerprint reader', 'Failed to match fingerprint']);
    expect(conversations, [
      _conversed(PamCode.success, [null]),
      _conversed(PamCode.success, [null, 'the password']),
    ]);
  });

  test('a second hidden prompt is not answered: the login asks for more than a password', () {
    late (int, List<String?>) second;
    final pam = FakePamLibrary(
      onAuthenticate: (pam) {
        pam.converse([_passwordPrompt]);
        second = pam.converse([(PamStyle.promptEchoOff, 'Verification code: ')]);
        return PamCode.conversationError;
      },
    );

    expect(
      () => _check(pam),
      throwsA(isA<PamUnexpectedPromptException>().having((e) => e.prompt, 'prompt', 'Verification code: ')),
    );
    expect(second, _conversed(PamCode.conversationError, []));
    expect(pam.ended, [PamCode.conversationError]);
  });

  test('a visible prompt is not answered either, even alongside the password prompt', () {
    late (int, List<String?>) conversation;
    final pam = FakePamLibrary(
      onAuthenticate: (pam) {
        conversation = pam.converse([_passwordPrompt, (PamStyle.promptEchoOn, 'One-time code: ')]);
        return PamCode.conversationError;
      },
    );

    expect(
      () => _check(pam),
      throwsA(isA<PamUnexpectedPromptException>().having((e) => e.prompt, 'prompt', 'One-time code: ')),
    );
    expect(conversation, _conversed(PamCode.conversationError, []));
  });

  test('a message of a kind PAM does not define ends the conversation', () {
    final pam = FakePamLibrary(
      onAuthenticate: (pam) {
        pam.converse([(99, 'what is this')]);
        return PamCode.conversationError;
      },
    );

    expect(() => _check(pam), throwsA(isA<PamUnexpectedPromptException>()));
  });

  test('any other PAM code is an error with the code and PAM\'s own text, and the transaction is still ended', () {
    final pam = FakePamLibrary(onAuthenticate: (_) => PamCode.authInfoUnavailable);

    expect(
      () => _check(pam),
      throwsA(
        isA<PamException>()
            .having((e) => e.code, 'code', PamCode.authInfoUnavailable)
            .having((e) => e.message, 'message', 'pam says ${PamCode.authInfoUnavailable}'),
      ),
    );
    expect(pam.ended, [PamCode.authInfoUnavailable]);
  });

  test('a transaction that cannot start is an error, and nothing is authenticated or ended', () {
    final pam = FakePamLibrary(startResult: PamCode.systemError);

    expect(() => _check(pam), throwsA(isA<PamException>().having((e) => e.code, 'code', PamCode.systemError)));
    expect(pam.authentications, 0);
    expect(pam.ended, isEmpty);
  });

  test('a failure while passing a message on is not hidden, and the transaction is still ended', () {
    final pam = FakePamLibrary(
      onAuthenticate: (pam) {
        final (code, _) = pam.converse([(PamStyle.textInfo, 'hello')]);
        return code;
      },
    );

    expect(
      () => checkPasswordWithPam(
        pam,
        service: 'quantus-wallet',
        user: 'alex',
        password: 'the password',
        onMessage: (_) => throw StateError('the listener is gone'),
      ),
      throwsStateError,
    );
    expect(pam.ended, [PamCode.conversationError]);
  });
}
