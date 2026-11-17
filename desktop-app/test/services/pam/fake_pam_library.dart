import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:quantus_desktop_wallet/services/pam/pam_library.dart';

/// libpam, played by a test: it records what the app asks of it, and its
/// "module" can talk to the app through the app's own conversation function,
/// in native memory laid out as libpam lays it out.
class FakePamLibrary implements PamLibrary {
  FakePamLibrary({this.onAuthenticate = _succeed, this.startResult = PamCode.success});

  /// What authenticating does: it may [converse], and answers PAM's code.
  final int Function(FakePamLibrary pam) onAuthenticate;

  /// What starting a transaction answers.
  final int startResult;

  String? service;
  String? user;
  int? flags;
  int authentications = 0;

  /// The status each transaction was ended with.
  final ended = <int>[];

  Pointer<PamConv>? _conversation;

  static final _handle = Pointer<Void>.fromAddress(0x5041);

  static int _succeed(FakePamLibrary pam) => PamCode.success;

  @override
  int start(Pointer<Utf8> service, Pointer<Utf8> user, Pointer<PamConv> conversation, Pointer<Pointer<Void>> handle) {
    this.service = service.toDartString();
    this.user = user.toDartString();
    _conversation = conversation;
    if (startResult == PamCode.success) handle.value = _handle;
    return startResult;
  }

  @override
  int authenticate(Pointer<Void> handle, int flags) {
    if (handle != _handle) throw StateError('Authenticated with a handle that start did not give.');
    this.flags = flags;
    authentications++;
    return onAuthenticate(this);
  }

  @override
  int end(Pointer<Void> handle, int status) {
    if (handle != _handle) throw StateError('Ended a handle that start did not give.');
    ended.add(status);
    return PamCode.success;
  }

  @override
  String errorText(Pointer<Void> handle, int code) => 'pam says $code';

  /// Sends [messages] to the app as a module does, and answers the app's
  /// return code with its answer to each message (null where it gave none).
  /// The answers are freed with libc's free, as libpam frees them.
  (int code, List<String?> answers) converse(List<(int style, String text)> messages) {
    final conversation = _conversation!.ref;
    final count = messages.length;
    final array = calloc<Pointer<PamMessage>>(count);
    for (final (index, (style, text)) in messages.indexed) {
      array[index] = calloc<PamMessage>()
        ..ref.msgStyle = style
        ..ref.msg = text.toNativeUtf8();
    }
    final responseOut = calloc<Pointer<PamResponse>>();

    try {
      final code = conversation.conv.asFunction<PamConversationDart>()(
        count,
        array,
        responseOut,
        conversation.appdataPtr,
      );
      final answers = <String?>[];
      if (code == PamCode.success) {
        final responses = responseOut.value;
        for (var index = 0; index < count; index++) {
          final answer = responses[index].resp;
          answers.add(answer == nullptr ? null : answer.toDartString());
          if (answer != nullptr) malloc.free(answer);
        }
        malloc.free(responses);
      }
      return (code, answers);
    } finally {
      for (var index = 0; index < count; index++) {
        calloc.free(array[index].ref.msg);
        calloc.free(array[index]);
      }
      calloc.free(array);
      calloc.free(responseOut);
    }
  }
}
