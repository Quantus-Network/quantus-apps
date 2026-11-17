import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_library.dart';

/// What PAM made of a password.
enum PamVerdict { accepted, refused }

/// PAM could not check the password at all.
class PamException implements Exception {
  const PamException(this.code, this.message);

  /// PAM's return code.
  final int code;

  /// What the code means, in PAM's words.
  final String message;

  @override
  String toString() => '$message (PAM error $code)';
}

/// The system's login asked for something other than the one password, such
/// as a one-time code. The app has no way to answer that, so nothing was
/// answered.
class PamUnexpectedPromptException implements Exception {
  const PamUnexpectedPromptException(this.prompt);

  /// What PAM asked.
  final String prompt;

  @override
  String toString() => 'The login asked for more than a password: $prompt';
}

/// Checks [password] for [user] against the PAM [service], in one PAM
/// transaction. What PAM says meanwhile (a fingerprint reader's instructions,
/// why an account is locked) goes to [onMessage].
///
/// It blocks until PAM answers, which takes seconds for a wrong password:
/// call it off the UI's isolate.
PamVerdict checkPasswordWithPam(
  PamLibrary pam, {
  required String service,
  required String user,
  required String password,
  required void Function(String message) onMessage,
}) {
  var isPasswordGiven = false;
  String? unexpectedPrompt;
  (Object, StackTrace)? failure;

  int converse(
    int count,
    Pointer<Pointer<PamMessage>> messages,
    Pointer<Pointer<PamResponse>> responses,
    Pointer<Void> _,
  ) {
    if (count <= 0 || count > pamMaxMessages) return PamCode.conversationError;
    // libpam frees the answers itself with free(), so they come from malloc.
    final answers = calloc<PamResponse>(count);
    try {
      for (var index = 0; index < count; index++) {
        final message = messages[index].ref;
        final text = message.msg == nullptr ? '' : message.msg.toDartString();
        switch (message.msgStyle) {
          case PamStyle.promptEchoOff when !isPasswordGiven:
            isPasswordGiven = true;
            answers[index].resp = password.toNativeUtf8(allocator: malloc);
          case PamStyle.errorMessage || PamStyle.textInfo:
            onMessage(text);
          default:
            unexpectedPrompt = text;
            _dropAnswers(answers, count);
            return PamCode.conversationError;
        }
      }
    } catch (error, stackTrace) {
      failure = (error, stackTrace);
      _dropAnswers(answers, count);
      return PamCode.conversationError;
    }
    responses.value = answers;
    return PamCode.success;
  }

  final conversation = NativeCallable<PamConversationNative>.isolateLocal(
    converse,
    exceptionalReturn: PamCode.conversationError,
  );
  try {
    return using((arena) {
      final conv = arena<PamConv>()
        ..ref.conv = conversation.nativeFunction
        ..ref.appdataPtr = nullptr;
      final handleOut = arena<Pointer<Void>>();

      final started = pam.start(
        service.toNativeUtf8(allocator: arena),
        user.toNativeUtf8(allocator: arena),
        conv,
        handleOut,
      );
      if (started != PamCode.success) throw PamException(started, pam.errorText(nullptr, started));
      final handle = handleOut.value;

      final status = pam.authenticate(handle, PamFlag.disallowNullAuthtok);
      // Read while the handle is still good.
      final statusText = pam.errorText(handle, status);
      pam.end(handle, status);

      if (failure case (final error, final stackTrace)?) Error.throwWithStackTrace(error, stackTrace);
      if (unexpectedPrompt case final prompt?) throw PamUnexpectedPromptException(prompt);
      return switch (status) {
        PamCode.success => PamVerdict.accepted,
        PamCode.authError || PamCode.maxTries || PamCode.permissionDenied => PamVerdict.refused,
        _ => throw PamException(status, statusText),
      };
    });
  } finally {
    conversation.close();
  }
}

/// Frees answers that PAM will not get, wiping the password's copy first.
void _dropAnswers(Pointer<PamResponse> answers, int count) {
  for (var index = 0; index < count; index++) {
    final answer = answers[index].resp;
    if (answer == nullptr) continue;
    final bytes = answer.cast<Uint8>();
    for (var offset = 0; bytes[offset] != 0; offset++) {
      bytes[offset] = 0;
    }
    malloc.free(answer);
  }
  calloc.free(answers);
}
