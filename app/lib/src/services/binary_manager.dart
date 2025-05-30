/// quantus_sdk/lib/src/services/binary_manager.dart
library binary_manager;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class BinaryManager {
  static const _repoOwner = 'Quantus-Network';
  static const _repoName = 'chain';
  static const _binary = 'quantus-node';

  static Future<String> getQuantusHomeDirectoryPath() async {
    return p.join(_home(), '.quantus');
  }

  static Future<String> getNodeBinaryFilePath() async {
    final cacheDir = await _cacheDir();
    return p.join(cacheDir.path, _binary);
  }

  static Future<bool> hasBinary() async {
    final cacheDir = await _cacheDir();
    final binPath = p.join(cacheDir.path, _binary);
    final binaryExists = await File(binPath).exists();
    return binaryExists;
  }

  static Future<File> ensureNodeBinary() async {
    final cacheDir = await _cacheDir();
    final binPath = p.join(cacheDir.path, _binary);

    // 1. already downloaded?
    if (await File(binPath).exists()) return File(binPath);

    // 2. find latest tag on GitHub
    final rel = await http.get(Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'));
    final tag = jsonDecode(rel.body)['tag_name'] as String;

    print('found latest tag: $tag');

    // 3. pick asset name like the shell script
    final target = _targetTriple();
    final asset = '$_binary-$tag-$target.tar.gz';
    final url = 'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/$asset';

    // 4. download
    final tgz = File(p.join(cacheDir.path, asset));
    final res = await http.get(Uri.parse(url));
    await tgz.writeAsBytes(res.bodyBytes);

    // 5. extract
    await Process.run('tar', ['-xzf', tgz.path, '-C', cacheDir.path]);
    if (!Platform.isWindows) await Process.run('chmod', ['+x', binPath]);

    return File(binPath);
  }

  /* helpers */
  static Future<Directory> _cacheDir() async => Directory(p.join(_home(), '.quantus', 'bin')).create(recursive: true);

  static String _home() => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;

  static String _targetTriple() {
    final os = Platform.isMacOS ? 'apple-darwin' : 'unknown-linux-gnu';
    final arch = Platform.version.contains('arm64') || Platform.version.contains('aarch64') ? 'aarch64' : 'x86_64';
    return '$arch-$os';
  }
}
