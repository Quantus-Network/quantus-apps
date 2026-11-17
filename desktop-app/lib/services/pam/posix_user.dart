import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _GetuidNative = Uint32 Function();
typedef _GetuidDart = int Function();

typedef _GetpwuidRNative =
    Int Function(
      Uint32 uid,
      Pointer<Void> entry,
      Pointer<Uint8> buffer,
      Size bufferSize,
      Pointer<Pointer<Void>> result,
    );
typedef _GetpwuidRDart =
    int Function(int uid, Pointer<Void> entry, Pointer<Uint8> buffer, int bufferSize, Pointer<Pointer<Void>> result);

/// `ERANGE`: the buffer handed to `getpwuid_r` was too small.
const _rangeError = 34;

/// Room for a `struct passwd` on any system the app runs on.
const _entrySize = 256;

const _largestBuffer = 1 << 20;

/// The name of the user this process runs as, from the system's user
/// database. The `USER` environment variable is whatever the process was
/// started with, so it is not asked.
String currentUserName() {
  final libc = DynamicLibrary.process();
  final uid = libc.lookupFunction<_GetuidNative, _GetuidDart>('getuid')();
  final getpwuidR = libc.lookupFunction<_GetpwuidRNative, _GetpwuidRDart>('getpwuid_r');

  return using((arena) {
    final entry = arena<Uint8>(_entrySize).cast<Void>();
    final result = arena<Pointer<Void>>();

    for (var size = 1024; size <= _largestBuffer; size *= 2) {
      final status = getpwuidR(uid, entry, arena<Uint8>(size), size, result);
      if (status == _rangeError) continue;
      if (status != 0) throw StateError('Looking up user $uid failed with error $status.');
      if (result.value == nullptr) throw StateError('The system has no user with id $uid.');
      // `pw_name` is the first member of `struct passwd` on Linux and macOS.
      return result.value.cast<Pointer<Utf8>>().value.toDartString();
    }
    throw StateError('The entry of user $uid does not fit in $_largestBuffer bytes.');
  });
}
