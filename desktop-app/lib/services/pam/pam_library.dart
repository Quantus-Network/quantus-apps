import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// The return codes of Linux-PAM that the app tells apart (`_pam_types.h`).
abstract final class PamCode {
  static const success = 0;
  static const systemError = 4;
  static const permissionDenied = 6;
  static const authError = 7;
  static const authInfoUnavailable = 9;
  static const maxTries = 11;
  static const conversationError = 19;
}

/// What a message in a PAM conversation is (`pam_message.msg_style`).
abstract final class PamStyle {
  /// A question whose answer must not be shown: the password.
  static const promptEchoOff = 1;

  /// A question whose answer may be shown, such as a one-time code.
  static const promptEchoOn = 2;
  static const errorMessage = 3;
  static const textInfo = 4;
}

/// The flags of `pam_authenticate`.
abstract final class PamFlag {
  /// An account with no password does not authenticate.
  static const disallowNullAuthtok = 0x0001;
}

/// The most messages PAM sends in one call (`PAM_MAX_NUM_MSG`).
const pamMaxMessages = 32;

/// `struct pam_message`.
final class PamMessage extends Struct {
  @Int()
  external int msgStyle;

  external Pointer<Utf8> msg;
}

/// `struct pam_response`.
final class PamResponse extends Struct {
  external Pointer<Utf8> resp;

  @Int()
  external int respRetcode;
}

/// The application's side of a PAM conversation. Linux-PAM hands the messages
/// over as an array of pointers.
typedef PamConversationNative =
    Int Function(
      Int count,
      Pointer<Pointer<PamMessage>> messages,
      Pointer<Pointer<PamResponse>> responses,
      Pointer<Void> appData,
    );
typedef PamConversationDart =
    int Function(
      int count,
      Pointer<Pointer<PamMessage>> messages,
      Pointer<Pointer<PamResponse>> responses,
      Pointer<Void> appData,
    );

/// `struct pam_conv`.
final class PamConv extends Struct {
  external Pointer<NativeFunction<PamConversationNative>> conv;

  external Pointer<Void> appdataPtr;
}

/// The calls of libpam that checking a password takes.
abstract interface class PamLibrary {
  /// `pam_start`.
  int start(Pointer<Utf8> service, Pointer<Utf8> user, Pointer<PamConv> conversation, Pointer<Pointer<Void>> handle);

  /// `pam_authenticate`.
  int authenticate(Pointer<Void> handle, int flags);

  /// `pam_end`.
  int end(Pointer<Void> handle, int status);

  /// `pam_strerror`: what [code] means, in PAM's words.
  String errorText(Pointer<Void> handle, int code);
}

/// The system's libpam.
class NativePamLibrary implements PamLibrary {
  NativePamLibrary(DynamicLibrary library)
    : _start = library.lookupFunction<_StartNative, _StartDart>('pam_start'),
      _authenticate = library.lookupFunction<_AuthenticateNative, _AuthenticateDart>('pam_authenticate'),
      _end = library.lookupFunction<_AuthenticateNative, _AuthenticateDart>('pam_end'),
      _strerror = library.lookupFunction<_StrerrorNative, _StrerrorDart>('pam_strerror');

  /// Opens the libpam every Linux system has. One without it fails here.
  factory NativePamLibrary.open() => NativePamLibrary(DynamicLibrary.open('libpam.so.0'));

  final _StartDart _start;
  final _AuthenticateDart _authenticate;
  final _AuthenticateDart _end;
  final _StrerrorDart _strerror;

  @override
  int start(Pointer<Utf8> service, Pointer<Utf8> user, Pointer<PamConv> conversation, Pointer<Pointer<Void>> handle) =>
      _start(service, user, conversation, handle);

  @override
  int authenticate(Pointer<Void> handle, int flags) => _authenticate(handle, flags);

  @override
  int end(Pointer<Void> handle, int status) => _end(handle, status);

  @override
  String errorText(Pointer<Void> handle, int code) => _strerror(handle, code).toDartString();
}

typedef _StartNative = Int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<PamConv>, Pointer<Pointer<Void>>);
typedef _StartDart = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<PamConv>, Pointer<Pointer<Void>>);

/// The shape of both `pam_authenticate(handle, flags)` and
/// `pam_end(handle, status)`.
typedef _AuthenticateNative = Int Function(Pointer<Void>, Int);
typedef _AuthenticateDart = int Function(Pointer<Void>, int);

typedef _StrerrorNative = Pointer<Utf8> Function(Pointer<Void>, Int);
typedef _StrerrorDart = Pointer<Utf8> Function(Pointer<Void>, int);
