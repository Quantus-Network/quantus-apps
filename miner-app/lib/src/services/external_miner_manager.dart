import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ExternalMinerManager {
  static const _repoOwner = 'Quantus-Network';
  static const _repoName = 'quantus-miner';
  static const _binary = 'external-miner';

  static Future<String> getExternalMinerBinaryFilePath() async {
    final cacheDir = await _getCacheDir();
    return p.join(cacheDir.path, _binary);
  }

  static Future<bool> hasExternalMinerBinary() async {
    final binPath = await getExternalMinerBinaryFilePath();
    return File(binPath).exists();
  }

  static Future<File> ensureExternalMinerBinary({
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final binPath = await getExternalMinerBinaryFilePath();
    final binFile = File(binPath);

    if (await binFile.exists()) {
      // If file exists, report 100% progress and return
      onProgress?.call(
        DownloadProgress(1, 1),
      ); // Simulate 100% if already downloaded
      return binFile;
    }

    // 2. find latest tag on GitHub
    final rel = await http.get(
      Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      ),
    );
    final tag = jsonDecode(rel.body)['tag_name'] as String;

    print('found latest external miner tag: $tag');

    // 3. pick asset name like the shell script
    final target = _targetTriple();
    final asset = '$_binary-$tag-$target.tar.gz';
    final url =
        'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/$asset';

    // 4. download
    final cacheDir = await _getCacheDir();
    final tgz = File(p.join(cacheDir.path, asset));

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download external miner binary: ${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final totalBytes = response.contentLength ?? -1;
      int downloadedBytes = 0;
      List<int> allBytes = [];

      await for (var chunk in response.stream) {
        allBytes.addAll(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(DownloadProgress(downloadedBytes, totalBytes));
        } else {
          // If totalBytes is unknown, we can't show a percentage,
          // but we can still report bytes downloaded if needed, or just a generic progress.
          // For now, let's report progress with totalBytes as 0 if unknown.
          onProgress?.call(DownloadProgress(downloadedBytes, 0));
        }
      }
      await tgz.writeAsBytes(allBytes);
      // Ensure 100% is reported at the end if not already due to chunking.
      if (totalBytes > 0 && downloadedBytes < totalBytes) {
        // This case should ideally not happen if stream ends correctly.
        onProgress?.call(DownloadProgress(totalBytes, totalBytes));
      } else if (totalBytes <= 0 && downloadedBytes > 0) {
        // If total was unknown, still send a final "completed" with what we got.
        onProgress?.call(DownloadProgress(downloadedBytes, downloadedBytes));
      }
    } finally {
      client.close();
    }

    // 5. extract
    await Process.run('tar', ['-xzf', tgz.path, '-C', cacheDir.path]);
    if (!Platform.isWindows) await Process.run('chmod', ['+x', binPath]);

    return binFile;
  }

  /* helpers */
  static Future<Directory> _getCacheDir() async {
    // Import the function from BinaryManager
    final quantusHome = await _getQuantusHomeDirectoryPath();
    return Directory(p.join(quantusHome, 'bin')).create(recursive: true);
  }

  static Future<String> _getQuantusHomeDirectoryPath() async {
    final dir = Directory(p.join(_home(), '.quantus'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static String _home() =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;

  static String _targetTriple() {
    final os = Platform.isMacOS ? 'apple-darwin' : 'unknown-linux-gnu';
    final arch =
        Platform.version.contains('arm64') ||
            Platform.version.contains('aarch64')
        ? 'aarch64'
        : 'x86_64';
    return '$arch-$os';
  }
}

// Re-use the DownloadProgress class from BinaryManager
class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;

  DownloadProgress(this.downloadedBytes, this.totalBytes);
}
