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
    final dir = Directory(p.join(_home(), '.quantus'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<String> getNodeBinaryFilePath() async {
    final cacheDir = await _getCacheDir();
    return p.join(cacheDir.path, _binary);
  }

  static Future<bool> hasBinary() async {
    final binPath = await getNodeBinaryFilePath();
    return File(binPath).exists();
  }

  static Future<File> ensureNodeBinary() async {
    final binPath = await getNodeBinaryFilePath();
    final binFile = File(binPath);

    if (await binFile.exists()) return binFile;

    // 2. find latest tag on GitHub
    final rel = await http.get(Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'));
    final tag = jsonDecode(rel.body)['tag_name'] as String;

    print('found latest tag: $tag');

    // 3. pick asset name like the shell script
    final target = _targetTriple();
    final asset = '$_binary-$tag-$target.tar.gz';
    final url = 'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/$asset';

    // 4. download
    final cacheDir = await _getCacheDir();
    final tgz = File(p.join(cacheDir.path, asset));
    final res = await http.get(Uri.parse(url));
    await tgz.writeAsBytes(res.bodyBytes);

    // 5. extract
    await Process.run('tar', ['-xzf', tgz.path, '-C', cacheDir.path]);
    if (!Platform.isWindows) await Process.run('chmod', ['+x', binPath]);

    return binFile;
  }

  static Future<File> getNodeKeyFile() async {
    final quantusHome = await getQuantusHomeDirectoryPath();
    final nodeKeyFile = File(p.join(quantusHome, 'node_key.p2p'));
    return nodeKeyFile;
  }

  static Future<File> ensureNodeKeyFile() async {
    final nodeKeyFile = await getNodeKeyFile();

    // Crude check: if file exists and is not empty or dummy, assume it's ok.
    // A more robust check would be to try to parse it, but that's complex.
    if (await nodeKeyFile.exists()) {
      final content = await nodeKeyFile.readAsString();
      if (content.trim().isNotEmpty && content.trim() != 'dummy_node_key_content_for_testing') {
        print('Node key file already exists and seems valid: $content');
        return nodeKeyFile;
      }
    }

    print('Node key file not found or invalid. Generating new key...');
    final nodeBinaryPath = await getNodeBinaryFilePath();
    if (!await File(nodeBinaryPath).exists()) {
      throw Exception(
          'Cannot generate node key: quantus-node binary not found at $nodeBinaryPath. Run ensureNodeBinary first.');
    }

    try {
      final processResult = await Process.run(
        nodeBinaryPath,
        ['key', 'generate-node-key'], // Common Substrate command
      );

      if (processResult.exitCode == 0) {
        final outputLines = processResult.stdout.toString().trim().split('\n');
        // if (outputLines.length < 2) {
        //   throw Exception(
        //       'Failed to generate node key: command output did not contain enough lines. Output: ${processResult.stdout}');
        // }
        final nodeKey = outputLines.last.trim(); // The secret key is the last line

        if (nodeKey.isEmpty) {
          throw Exception(
              'Failed to generate node key: extracted secret key was empty. Stderr: ${processResult.stderr}');
        }
        await nodeKeyFile.writeAsString(nodeKey);
        print('Successfully generated and saved node key: $nodeKey');
        return nodeKeyFile;
      } else {
        throw Exception(
            'Failed to generate node key. Exit code: ${processResult.exitCode}\nStderr: ${processResult.stderr}\nStdout: ${processResult.stdout}');
      }
    } catch (e) {
      print('Error generating node key: $e');
      rethrow; // Rethrow the exception to be handled by the caller
    }
  }

  /* helpers */
  static Future<Directory> _getCacheDir() async =>
      Directory(p.join(await getQuantusHomeDirectoryPath(), 'bin')).create(recursive: true);

  static String _home() => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;

  static String _targetTriple() {
    final os = Platform.isMacOS ? 'apple-darwin' : 'unknown-linux-gnu';
    final arch = Platform.version.contains('arm64') || Platform.version.contains('aarch64') ? 'aarch64' : 'x86_64';
    return '$arch-$os';
  }
}
