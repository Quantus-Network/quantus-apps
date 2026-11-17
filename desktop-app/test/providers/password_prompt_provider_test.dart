import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/password_prompt_provider.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';

Future<LoginPasswordResult> _check(String password, {required void Function(String message) onMessage}) async =>
    LoginPasswordResult.accepted;

void main() {
  late ProviderContainer container;
  late PasswordPromptNotifier prompt;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    prompt = container.read(passwordPromptProvider.notifier);
  });

  test('holds a request, with its reason and its check, until the prompt is finished', () async {
    expect(container.read(passwordPromptProvider), isNull);

    final answer = prompt.ask(reason: 'Authenticate to see recovery phrase', check: _check);

    final request = container.read(passwordPromptProvider)!;
    expect(request.reason, 'Authenticate to see recovery phrase');
    expect(request.check, _check);

    prompt.finish(approved: true);

    expect(await answer, isTrue);
    expect(container.read(passwordPromptProvider), isNull);
  });

  test('a prompt that was cancelled answers no', () async {
    final answer = prompt.ask(reason: 'why', check: _check);

    prompt.finish(approved: false);

    expect(await answer, isFalse);
  });

  test('a prompt that failed answers with its error, and makes room for the next', () async {
    final answer = prompt.ask(reason: 'why', check: _check);

    prompt.fail(StateError('PAM is out of service'), StackTrace.current);

    await expectLater(answer, throwsStateError);
    expect(container.read(passwordPromptProvider), isNull);

    final next = prompt.ask(reason: 'again', check: _check);
    prompt.finish(approved: true);
    expect(await next, isTrue);
  });

  test('a second request while one is open is refused, and the open one is kept', () async {
    final answer = prompt.ask(reason: 'first', check: _check);

    expect(() => prompt.ask(reason: 'second', check: _check), throwsStateError);
    expect(container.read(passwordPromptProvider)!.reason, 'first');

    prompt.finish(approved: true);
    expect(await answer, isTrue);
  });

  test('finishing or failing with no prompt open is an error', () {
    expect(() => prompt.finish(approved: true), throwsStateError);
    expect(() => prompt.fail(StateError('x'), StackTrace.current), throwsStateError);
  });
}
