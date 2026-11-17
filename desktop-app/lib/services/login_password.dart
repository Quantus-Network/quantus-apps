import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_library.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_session.dart';
import 'package:quantus_desktop_wallet/services/pam/posix_user.dart';

/// What the system made of a login password.
enum LoginPasswordResult { accepted, refused }

/// Checks [password]; see [LoginPassword.check].
typedef LoginPasswordCheck =
    Future<LoginPasswordResult> Function(String password, {required void Function(String message) onMessage});

/// The login password of the person signed in to this computer, which the
/// system checks for the app.
abstract interface class LoginPassword {
  /// Whether the system has been set up to check the password for this app.
  /// A system that cannot check passwords at all is an error.
  Future<bool> isSetUp();

  /// Asks the system whether [password] is the login password. What the
  /// system says meanwhile, such as a fingerprint reader's instructions,
  /// goes to [onMessage]. A check that could not be made is an error.
  Future<LoginPasswordResult> check(String password, {required void Function(String message) onMessage});
}

/// The login password on Linux, checked through PAM under the app's own
/// service, whose file the app's package installs.
class PamLoginPassword implements LoginPassword {
  const PamLoginPassword({
    this.openLibrary = NativePamLibrary.open,
    this.currentUser = currentUserName,
    this.serviceDirectories = const ['/etc/pam.d', '/usr/lib/pam.d'],
  });

  /// The app's PAM service: the name of its file in a PAM directory.
  static const service = 'quantus-wallet';

  /// Opens libpam. The check calls it in an isolate of its own, so it must
  /// be a top-level or static function.
  final PamLibrary Function() openLibrary;

  /// Names the user whose password is checked; a top-level or static
  /// function, as [openLibrary] is.
  final String Function() currentUser;

  /// The directories every libpam reads service files from.
  final List<String> serviceDirectories;

  @override
  Future<bool> isSetUp() async {
    openLibrary();
    // Without its file libpam falls back on the service "other", which on
    // most systems refuses everyone: every password would look wrong.
    return serviceDirectories.any((directory) => File('$directory/$service').existsSync());
  }

  @override
  Future<LoginPasswordResult> check(String password, {required void Function(String message) onMessage}) async {
    // PAM blocks for seconds over a wrong password, so it gets an isolate.
    final events = ReceivePort();
    final result = Completer<LoginPasswordResult>();

    events.listen((event) {
      switch (event) {
        case _Said(:final message):
          onMessage(message);
        case _Answered(:final verdict):
          result.complete(switch (verdict) {
            PamVerdict.accepted => LoginPasswordResult.accepted,
            PamVerdict.refused => LoginPasswordResult.refused,
          });
        case _Failed(:final error, :final stackTrace):
          result.completeError(error, stackTrace);
        // An error the isolate did not catch, as [description, stack trace].
        case [final Object description, ...]:
          if (!result.isCompleted) result.completeError(StateError('The login password check failed: $description'));
        // The isolate has exited.
        case null:
          if (!result.isCompleted) result.completeError(StateError('The login password check ended with no answer.'));
          events.close();
      }
    });

    try {
      await Isolate.spawn(
        _checkInIsolate,
        (events: events.sendPort, openLibrary: openLibrary, currentUser: currentUser, password: password),
        onError: events.sendPort,
        onExit: events.sendPort,
      );
    } catch (_) {
      events.close();
      rethrow;
    }
    return result.future;
  }
}

typedef _CheckRequest = ({
  SendPort events,
  PamLibrary Function() openLibrary,
  String Function() currentUser,
  String password,
});

sealed class _CheckEvent {
  const _CheckEvent();
}

/// PAM said [message].
final class _Said extends _CheckEvent {
  const _Said(this.message);

  final String message;
}

final class _Answered extends _CheckEvent {
  const _Answered(this.verdict);

  final PamVerdict verdict;
}

final class _Failed extends _CheckEvent {
  const _Failed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

void _checkInIsolate(_CheckRequest request) {
  try {
    final verdict = checkPasswordWithPam(
      request.openLibrary(),
      service: PamLoginPassword.service,
      user: request.currentUser(),
      password: request.password,
      onMessage: (message) => request.events.send(_Said(message)),
    );
    request.events.send(_Answered(verdict));
  } catch (error, stackTrace) {
    request.events.send(_Failed(error, stackTrace));
  }
}

final loginPasswordProvider = Provider<LoginPassword>((ref) => const PamLoginPassword());
