import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keeps the one analytics user ID of this computer's app.
abstract interface class TelemetryUserStore {
  /// The user ID, made the first time it is asked for.
  Future<String> userId();
}

/// [TelemetryUserStore] in a file of the app's own, apart from the wallet's
/// preferences: a wallet reset wipes those, and must not make a new user of
/// the same person, as on the phone.
class FileTelemetryUserStore implements TelemetryUserStore {
  FileTelemetryUserStore({Future<Directory> Function() directory = getApplicationSupportDirectory})
    : _directory = directory;

  final Future<Directory> Function() _directory;

  @override
  Future<String> userId() async {
    final file = File('${(await _directory()).path}/telemetry_user.json');
    if (await file.exists()) {
      return (jsonDecode(await file.readAsString()) as Map<String, dynamic>)['userId'] as String;
    }
    final userId = const Uuid().v4();
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode({'userId': userId}), flush: true);
    return userId;
  }
}

final telemetryUserStoreProvider = Provider<TelemetryUserStore>((ref) => FileTelemetryUserStore());
