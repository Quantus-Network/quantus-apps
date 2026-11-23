import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';

/// A request for the login password: why it is asked for, and how to check
/// what the person types.
class PasswordPromptRequest {
  const PasswordPromptRequest({required this.reason, required this.check});

  final String reason;
  final LoginPasswordCheck check;
}

/// The request for the login password that is waiting for an answer, or null
/// when there is none. The shell shows it as a dialog over the window.
final passwordPromptProvider = NotifierProvider<PasswordPromptNotifier, PasswordPromptRequest?>(
  PasswordPromptNotifier.new,
);

class PasswordPromptNotifier extends Notifier<PasswordPromptRequest?> {
  Completer<bool>? _answer;

  @override
  PasswordPromptRequest? build() => null;

  /// Asks the person for their login password, telling them [reason], and
  /// answers whether a password they typed passed [check]: false if they
  /// gave up. One prompt at a time: a request made while one is open is an
  /// error.
  Future<bool> ask({required String reason, required LoginPasswordCheck check}) {
    if (_answer != null) throw StateError('A login password prompt is already open.');
    final answer = _answer = Completer<bool>();
    state = PasswordPromptRequest(reason: reason, check: check);
    return answer.future;
  }

  /// Called by the shell once the prompt has closed.
  void finish({required bool approved}) => _close().complete(approved);

  /// Called by the shell when the prompt closed because the check itself
  /// could not be made.
  void fail(Object error, StackTrace stackTrace) => _close().completeError(error, stackTrace);

  Completer<bool> _close() {
    final answer = _answer;
    if (answer == null) throw StateError('No login password prompt is open.');
    _answer = null;
    state = null;
    return answer;
  }
}
