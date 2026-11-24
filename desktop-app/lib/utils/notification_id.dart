import 'dart:convert';

/// The id the system knows the notification named [name] by: its FNV-1a hash
/// (32 bits, over its UTF-8), cut to the 31 bits the notification plugins
/// take.
///
/// The push server works out the same id for a notification it pushes about
/// the same thing, so that the one the app shows replaces the pushed one. It
/// must stay this function, and not Dart's `hashCode`, which another program
/// cannot repeat.
int notificationSystemId(String name) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(name)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
