import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// What the push service may hold of this Mac.
class MacPushHold {
  const MacPushHold({this.token, this.removalOwed = false});

  /// The token the push service may hold this Mac's registration under; null
  /// when it holds none.
  final String? token;

  /// Whether a removal was asked for and has not gone through yet.
  final bool removalOwed;

  static const none = MacPushHold();

  factory MacPushHold.fromJson(Map<String, dynamic> json) =>
      MacPushHold(token: json['token'] as String?, removalOwed: json['removalOwed'] as bool);

  Map<String, Object?> toJson() => {'token': token, 'removalOwed': removalOwed};
}

/// Keeps [MacPushHold] across launches, apart from the wallet's preferences:
/// a reset wipes those, and a removal it could not make must still be made.
abstract interface class MacPushStore {
  Future<MacPushHold> read();

  Future<void> write(MacPushHold hold);
}

/// [MacPushStore] in a file of the app's own, which a reset leaves in place.
class FileMacPushStore implements MacPushStore {
  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/mac_push.json');

  @override
  Future<MacPushHold> read() async {
    final file = await _file();
    if (!await file.exists()) return MacPushHold.none;
    return MacPushHold.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  }

  @override
  Future<void> write(MacPushHold hold) async {
    await (await _file()).writeAsString(jsonEncode(hold.toJson()), flush: true);
  }
}

final macPushStoreProvider = Provider<MacPushStore>((ref) => FileMacPushStore());
