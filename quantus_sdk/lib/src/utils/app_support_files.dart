import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> appSupportFile(String name) async => File('${(await getApplicationSupportDirectory()).path}/$name');

String appSupportFileName(FileSystemEntity entity) =>
    entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last;

/// Deletes the files in the app support directory whose name [matches] and
/// returns how many were deleted.
Future<int> deleteAppSupportFiles(bool Function(String name) matches) async {
  final dir = await getApplicationSupportDirectory();
  if (!await dir.exists()) return 0;
  var deleted = 0;
  await for (final entity in dir.list()) {
    if (entity is! File || !matches(appSupportFileName(entity))) continue;
    await entity.delete();
    deleted++;
  }
  return deleted;
}
