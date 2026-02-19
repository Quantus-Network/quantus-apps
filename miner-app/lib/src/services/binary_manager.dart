import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('BinaryManager');

class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;

  DownloadProgress(this.downloadedBytes, this.totalBytes);
}

class BinaryVersion {
  final String version;
  final DateTime checkedAt;

  BinaryVersion(this.version, this.checkedAt);

  Map<String, dynamic> toJson() => {'version': version, 'checkedAt': checkedAt.toIso8601String()};

  factory BinaryVersion.fromJson(Map<String, dynamic> json) =>
      BinaryVersion(json['version'] as String, DateTime.parse(json['checkedAt'] as String));
}

class BinaryUpdateInfo {
  final bool updateAvailable;
  final String? currentVersion;
  final String? latestVersion;
  final String? downloadUrl;

  BinaryUpdateInfo({required this.updateAvailable, this.currentVersion, this.latestVersion, this.downloadUrl});
}

class BinaryManager {
  static const _repoOwner = 'Quantus-Network';
  static const _repoName = 'chain';
  static const _binary = 'quantus-node';

  // External miner constants
  static const _minerRepoName = 'quantus-miner';
  static const _minerBinary = 'quantus-miner';
  static const _minerReleaseBinary = 'quantus-miner';

  // Version file names
  static const _nodeVersionFile = 'node_version.json';
  static const _minerVersionFile = 'miner_version.json';

  static Future<String> getQuantusHomeDirectoryPath() async {
    final dir = Directory(p.join(_home(), '.quantus'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<String> getNodeBinaryFilePath() async {
    final cacheDir = await _getCacheDir();
    return p.join(cacheDir.path, _normalizeFilename(_binary));
  }

  static Future<String> getExternalMinerBinaryFilePath() async {
    final cacheDir = await _getCacheDir();
    return p.join(cacheDir.path, _normalizeFilename(_minerBinary));
  }

  static Future<bool> hasBinary() async {
    final binPath = await getNodeBinaryFilePath();
    return File(binPath).exists();
  }

  static Future<bool> hasExternalMinerBinary() async {
    final binPath = await getExternalMinerBinaryFilePath();
    return File(binPath).exists();
  }

  // Version tracking methods
  static Future<BinaryVersion?> getNodeBinaryVersion() async {
    final quantusHome = await getQuantusHomeDirectoryPath();
    final versionFile = File(p.join(quantusHome, _nodeVersionFile));

    if (!await versionFile.exists()) {
      return null;
    }

    try {
      final content = await versionFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return BinaryVersion.fromJson(json);
    } catch (e) {
      _log.d('Error reading node version file: $e');
      return null;
    }
  }

  static Future<BinaryVersion?> getMinerBinaryVersion() async {
    final quantusHome = await getQuantusHomeDirectoryPath();
    final versionFile = File(p.join(quantusHome, _minerVersionFile));

    if (!await versionFile.exists()) {
      return null;
    }

    try {
      final content = await versionFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return BinaryVersion.fromJson(json);
    } catch (e) {
      _log.d('Error reading miner version file: $e');
      return null;
    }
  }

  static Future<void> _saveNodeVersion(String version) async {
    final quantusHome = await getQuantusHomeDirectoryPath();
    final versionFile = File(p.join(quantusHome, _nodeVersionFile));
    final binaryVersion = BinaryVersion(version, DateTime.now());
    await versionFile.writeAsString(jsonEncode(binaryVersion.toJson()));
  }

  static Future<void> _saveMinerVersion(String version) async {
    final quantusHome = await getQuantusHomeDirectoryPath();
    final versionFile = File(p.join(quantusHome, _minerVersionFile));
    final binaryVersion = BinaryVersion(version, DateTime.now());
    await versionFile.writeAsString(jsonEncode(binaryVersion.toJson()));
  }

  static Future<String> getLatestNodeVersion() async {
    final rel = await http.get(Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'));

    if (rel.statusCode != 200) {
      throw Exception('Failed to fetch latest node version: ${rel.statusCode}');
    }

    return jsonDecode(rel.body)['tag_name'] as String;
  }

  static Future<String> getLatestMinerVersion() async {
    final rel = await http.get(Uri.parse('https://api.github.com/repos/$_repoOwner/$_minerRepoName/releases/latest'));

    if (rel.statusCode != 200) {
      throw Exception('Failed to fetch latest miner version: ${rel.statusCode}');
    }

    return jsonDecode(rel.body)['tag_name'] as String;
  }

  static Future<BinaryUpdateInfo> checkNodeUpdate() async {
    try {
      final currentVersion = await getNodeBinaryVersion();
      final latestVersion = await getLatestNodeVersion();

      if (currentVersion == null) {
        return BinaryUpdateInfo(
          updateAvailable: true,
          latestVersion: latestVersion,
          downloadUrl: _buildNodeDownloadUrl(latestVersion),
        );
      }

      final updateAvailable = _isNewerVersion(currentVersion.version, latestVersion);

      return BinaryUpdateInfo(
        updateAvailable: updateAvailable,
        currentVersion: currentVersion.version,
        latestVersion: latestVersion,
        downloadUrl: updateAvailable ? _buildNodeDownloadUrl(latestVersion) : null,
      );
    } catch (e) {
      _log.w('Error checking node update', error: e);
      return BinaryUpdateInfo(updateAvailable: false);
    }
  }

  static Future<BinaryUpdateInfo> checkMinerUpdate() async {
    try {
      final currentVersion = await getMinerBinaryVersion();
      final latestVersion = await getLatestMinerVersion();

      if (currentVersion == null) {
        return BinaryUpdateInfo(
          updateAvailable: true,
          latestVersion: latestVersion,
          downloadUrl: _buildMinerDownloadUrl(latestVersion),
        );
      }

      final updateAvailable = _isNewerVersion(currentVersion.version, latestVersion);

      return BinaryUpdateInfo(
        updateAvailable: updateAvailable,
        currentVersion: currentVersion.version,
        latestVersion: latestVersion,
        downloadUrl: updateAvailable ? _buildMinerDownloadUrl(latestVersion) : null,
      );
    } catch (e) {
      _log.w('Error checking miner update', error: e);
      return BinaryUpdateInfo(updateAvailable: false);
    }
  }

  static String _buildNodeDownloadUrl(String tag) {
    final target = _targetTriple();
    final extension = Platform.isWindows ? "zip" : "tar.gz";
    final asset = '$_binary-$tag-$target.$extension';
    return 'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/$asset';
  }

  static String _buildMinerDownloadUrl(String tag) {
    String platform;
    String arch;

    if (Platform.isMacOS) {
      platform = 'macos';
    } else if (Platform.isLinux) {
      platform = 'linux';
    } else if (Platform.isWindows) {
      platform = 'windows';
    } else {
      throw Exception('Unsupported platform: ${Platform.operatingSystem}');
    }

    if (Platform.isWindows) {
      // Force x86_64 on Windows to support x64 emulation on ARM devices
      // unless we specifically start releasing native ARM64 Windows binaries
      arch = 'x86_64';
    } else if (Platform.version.contains('arm64') || Platform.version.contains('aarch64')) {
      arch = 'aarch64';
    } else {
      arch = 'x86_64';
    }

    final asset = Platform.isWindows
        ? '$_minerReleaseBinary-$platform-$arch.exe'
        : '$_minerReleaseBinary-$platform-$arch';

    return 'https://github.com/$_repoOwner/$_minerRepoName/releases/download/$tag/$asset';
  }

  static bool _isNewerVersion(String current, String latest) {
    // Remove 'v' prefix if present
    final currentClean = current.startsWith('v') ? current.substring(1) : current;
    final latestClean = latest.startsWith('v') ? latest.substring(1) : latest;

    final currentParts = currentClean.split('.').map(int.tryParse).toList();
    final latestParts = latestClean.split('.').map(int.tryParse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;

      final currentPart = currentParts[i] ?? 0;
      final latestPart = latestParts[i] ?? 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }

  static Future<File> ensureNodeBinary({
    void Function(DownloadProgress progress)? onProgress,
    bool forceDownload = false,
  }) async {
    final binPath = await getNodeBinaryFilePath();
    final binFile = File(binPath);

    if (await binFile.exists() && !forceDownload) {
      onProgress?.call(DownloadProgress(1, 1));
      return binFile;
    }

    return await _downloadNodeBinary(onProgress: onProgress);
  }

  static Future<File> updateNodeBinary({void Function(DownloadProgress progress)? onProgress}) async {
    _log.i('Updating node binary to latest version...');

    final binPath = await getNodeBinaryFilePath();
    final binFile = File(binPath);
    final backupPath = '$binPath.backup';
    final backupFile = File(backupPath);

    // Create backup of existing binary if it exists
    if (await binFile.exists()) {
      _log.d('Creating backup of existing binary...');
      await binFile.copy(backupPath);
      _log.d('Backup created at: $backupPath');
    }

    try {
      // Download to temporary location first
      final newBinary = await _downloadNodeBinary(onProgress: onProgress, isUpdate: true);

      // If download successful, replace the old binary
      if (await backupFile.exists()) {
        await backupFile.delete();
        _log.d('Backup removed after successful update');
      }

      _log.i('Node binary updated successfully!');
      return newBinary;
    } catch (e) {
      // If download failed, restore from backup
      _log.e('Download failed', error: e);
      if (await backupFile.exists()) {
        _log.i('Restoring from backup...');
        await backupFile.copy(binPath);
        await backupFile.delete();
        _log.i('Binary restored from backup');
      }
      rethrow;
    }
  }

  static Future<File> _downloadNodeBinary({
    void Function(DownloadProgress progress)? onProgress,
    bool isUpdate = false,
  }) async {
    // Find latest tag on GitHub
    final rel = await http.get(Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'));
    final tag = jsonDecode(rel.body)['tag_name'] as String;

    _log.d('Found latest tag: $tag');

    // Pick asset name
    final target = _targetTriple();
    final extension = Platform.isWindows ? "zip" : "tar.gz";
    final asset = '$_binary-$tag-$target.$extension';
    final url = 'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/$asset';

    // Download
    final cacheDir = await _getCacheDir();
    final tgz = File(p.join(cacheDir.path, asset));

    // Use temporary path for extraction during updates
    final tempExtractDir = isUpdate ? Directory(p.join(cacheDir.path, 'temp_update')) : cacheDir;

    if (isUpdate && await tempExtractDir.exists()) {
      await tempExtractDir.delete(recursive: true);
    }
    if (isUpdate) {
      await tempExtractDir.create(recursive: true);
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download binary: ${response.statusCode} ${response.reasonPhrase}');
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
          onProgress?.call(DownloadProgress(downloadedBytes, 0));
        }
      }
      await tgz.writeAsBytes(allBytes);

      if (totalBytes > 0 && downloadedBytes < totalBytes) {
        onProgress?.call(DownloadProgress(totalBytes, totalBytes));
      } else if (totalBytes <= 0 && downloadedBytes > 0) {
        onProgress?.call(DownloadProgress(downloadedBytes, downloadedBytes));
      }
    } finally {
      client.close();
    }

    // Extract to temporary directory if updating
    await Process.run('tar', ['-xzf', tgz.path, '-C', tempExtractDir.path]);

    final tempBinPath = p.join(tempExtractDir.path, _normalizeFilename(_binary));
    final finalBinPath = await getNodeBinaryFilePath();

    if (!Platform.isWindows) await Process.run('chmod', ['+x', tempBinPath]);

    // Move from temp to final location (atomic operation)
    if (isUpdate) {
      final tempBinFile = File(tempBinPath);
      if (await tempBinFile.exists()) {
        await tempBinFile.copy(finalBinPath);
        await tempExtractDir.delete(recursive: true);
      } else {
        throw Exception('Extracted binary not found at expected location');
      }
    }

    // Save version info
    await _saveNodeVersion(tag);

    return File(finalBinPath);
  }

  static Future<File> ensureExternalMinerBinary({
    void Function(DownloadProgress progress)? onProgress,
    bool forceDownload = false,
  }) async {
    final binPath = await getExternalMinerBinaryFilePath();
    final binFile = File(binPath);

    _log.d('Checking for external miner at path: $binPath');

    if (await binFile.exists() && !forceDownload) {
      _log.d('External miner binary already exists at $binPath');
      onProgress?.call(DownloadProgress(1, 1));
      return binFile;
    }

    return await _downloadMinerBinary(onProgress: onProgress);
  }

  static Future<File> updateMinerBinary({void Function(DownloadProgress progress)? onProgress}) async {
    _log.i('Updating miner binary to latest version...');

    final binPath = await getExternalMinerBinaryFilePath();
    final binFile = File(binPath);
    final backupPath = '$binPath.backup';
    final backupFile = File(backupPath);

    // Create backup of existing binary if it exists
    if (await binFile.exists()) {
      _log.d('Creating backup of existing miner binary...');
      await binFile.copy(backupPath);
      _log.d('Backup created at: $backupPath');
    }

    try {
      // Download to temporary location first
      final newBinary = await _downloadMinerBinary(onProgress: onProgress, isUpdate: true);

      // If download successful, replace the old binary
      if (await backupFile.exists()) {
        await backupFile.delete();
        _log.d('Backup removed after successful update');
      }

      _log.i('Miner binary updated successfully!');
      return newBinary;
    } catch (e) {
      // If download failed, restore from backup
      _log.e('Download failed', error: e);
      if (await backupFile.exists()) {
        _log.i('Restoring from backup...');
        await backupFile.copy(binPath);
        await backupFile.delete();
        _log.i('Binary restored from backup');
      }
      rethrow;
    }
  }

  static Future<File> _downloadMinerBinary({
    void Function(DownloadProgress progress)? onProgress,
    bool isUpdate = false,
  }) async {
    _log.d('External miner binary download process starting...');

    // Find latest tag on GitHub
    final releaseUrl = 'https://api.github.com/repos/$_repoOwner/$_minerRepoName/releases/latest';
    _log.d('Fetching latest release from: $releaseUrl');

    final rel = await http.get(Uri.parse(releaseUrl));

    final releaseData = jsonDecode(rel.body);
    final tag = releaseData['tag_name'] as String;

    _log.d('Found latest external miner tag: $tag');

    // Pick asset name
    String platform;
    String arch;

    if (Platform.isMacOS) {
      platform = 'macos';
    } else if (Platform.isLinux) {
      platform = 'linux';
    } else if (Platform.isWindows) {
      platform = 'windows';
    } else {
      throw Exception('Unsupported platform: ${Platform.operatingSystem}');
    }

    if (Platform.isWindows) {
      // Force x86_64 on Windows to support x64 emulation on ARM devices
      // unless we specifically start releasing native ARM64 Windows binaries
      arch = 'x86_64';
    } else if (Platform.version.contains('arm64') || Platform.version.contains('aarch64')) {
      arch = 'aarch64';
    } else {
      arch = 'x86_64';
    }

    final asset = Platform.isWindows
        ? '$_minerReleaseBinary-$platform-$arch.exe'
        : '$_minerReleaseBinary-$platform-$arch';

    _log.d('Looking for asset: $asset');

    final url = 'https://github.com/$_repoOwner/$_minerRepoName/releases/download/$tag/$asset';

    // Check if the asset exists in the release
    final assets = releaseData['assets'] as List;
    _log.d('Available assets in release:');
    bool assetFound = false;
    for (var assetInfo in assets) {
      _log.d('  - ${assetInfo['name']} (${assetInfo['browser_download_url']})');
      if (assetInfo['name'] == asset) {
        assetFound = true;
      }
    }

    if (!assetFound) {
      throw Exception(
        'Asset $asset not found in release. Available assets: ${assets.map((a) => a['name']).join(', ')}',
      );
    }

    // Download the binary to temporary location
    final cacheDir = await _getCacheDir();
    final tempFileName = isUpdate ? '$asset.tmp' : asset;
    final tempBinaryFile = File(p.join(cacheDir.path, tempFileName));
    _log.d('Will download to: ${tempBinaryFile.path}');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      _log.d('Download response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Failed to download external miner binary: ${response.statusCode} ${response.reasonPhrase}');
      }

      final totalBytes = response.contentLength ?? -1;
      _log.d('Expected download size: $totalBytes bytes');
      int downloadedBytes = 0;
      List<int> allBytes = [];

      await for (var chunk in response.stream) {
        allBytes.addAll(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(DownloadProgress(downloadedBytes, totalBytes));
        } else {
          onProgress?.call(DownloadProgress(downloadedBytes, 0));
        }
      }
      await tempBinaryFile.writeAsBytes(allBytes);
      _log.d('Downloaded ${allBytes.length} bytes to ${tempBinaryFile.path}');

      if (totalBytes > 0 && downloadedBytes < totalBytes) {
        onProgress?.call(DownloadProgress(totalBytes, totalBytes));
      } else if (totalBytes <= 0 && downloadedBytes > 0) {
        onProgress?.call(DownloadProgress(downloadedBytes, downloadedBytes));
      }
    } finally {
      client.close();
    }

    // Set executable permissions on temp file
    if (!Platform.isWindows) {
      _log.d('Setting executable permissions on ${tempBinaryFile.path}');
      final chmodResult = await Process.run('chmod', ['+x', tempBinaryFile.path]);
      _log.d('chmod exit code: ${chmodResult.exitCode}');
      if (chmodResult.exitCode != 0) {
        _log.e('chmod stderr: ${chmodResult.stderr}');
        throw Exception('Failed to set executable permissions');
      }
    }

    // Move to final location (atomic operation)
    final binPath = await getExternalMinerBinaryFilePath();
    _log.d('Moving binary from ${tempBinaryFile.path} to $binPath');

    // Copy instead of rename for cross-device compatibility
    await tempBinaryFile.copy(binPath);
    await tempBinaryFile.delete();

    _log.d('Contents of cache directory after download:');
    final cacheDirContents = await cacheDir.list().toList();
    for (var item in cacheDirContents) {
      _log.d('  - ${item.path}');
    }

    // Final check
    final binFile = File(binPath);
    if (await binFile.exists()) {
      _log.i('External miner binary successfully created at $binPath');
      // Save version info
      await _saveMinerVersion(tag);
    } else {
      _log.e('External miner binary still not found at $binPath after download!');
      throw Exception('External miner binary not found after download at $binPath');
    }

    return binFile;
  }

  static Future<File> getNodeKeyFile() async {
    final quantusHome = await getQuantusHomeDirectoryPath();
    final nodeKeyFile = File(p.join(quantusHome, 'node_key.p2p'));
    return nodeKeyFile;
  }

  static Future<File> ensureNodeKeyFile() async {
    final nodeKeyFile = await getNodeKeyFile();

    if (await nodeKeyFile.exists()) {
      final stat = await nodeKeyFile.stat();
      if (stat.size > 0) {
        _log.d('Node key file already exists and has content (size: ${stat.size} bytes)');
        return nodeKeyFile;
      }
    }

    _log.i('Node key file not found or empty. Generating new key...');
    final nodeBinaryPath = await getNodeBinaryFilePath();
    if (!await File(nodeBinaryPath).exists()) {
      throw Exception(
        'Cannot generate node key: quantus-node binary not found at $nodeBinaryPath. Run ensureNodeBinary first.',
      );
    }

    try {
      final processResult = await Process.run(nodeBinaryPath, ['key', 'generate-node-key', '--file', nodeKeyFile.path]);

      if (processResult.exitCode == 0) {
        if (await nodeKeyFile.exists()) {
          final stat = await nodeKeyFile.stat();
          if (stat.size > 0) {
            _log.i('Successfully generated node key file: ${nodeKeyFile.path} (size: ${stat.size} bytes)');
            return nodeKeyFile;
          } else {
            throw Exception('Node key file was created but is empty');
          }
        } else {
          throw Exception('Node key file was not created');
        }
      } else {
        throw Exception(
          'Failed to generate node key. Exit code: ${processResult.exitCode}\nStderr: ${processResult.stderr}\nStdout: ${processResult.stdout}',
        );
      }
    } catch (e) {
      _log.e('Error generating node key', error: e);
      rethrow;
    }
  }

  static String _normalizeFilename(String file) => Platform.isWindows ? "$file.exe" : file;

  static Future<Directory> _getCacheDir() async =>
      Directory(p.join(await getQuantusHomeDirectoryPath(), 'bin')).create(recursive: true);

  static String _home() => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;

  static String _targetTriple() {
    final os = Platform.isMacOS ? 'apple-darwin' : (Platform.isWindows ? 'pc-windows-msvc' : 'unknown-linux-gnu');

    // Force x86_64 on Windows to ensure we download the x64 binary even on ARM devices
    // (since they can emulate x64, and we don't likely have a native ARM build for Windows yet)
    if (Platform.isWindows) {
      return 'x86_64-$os';
    }

    final arch = Platform.version.contains('arm64') || Platform.version.contains('aarch64') ? 'aarch64' : 'x86_64';
    return '$arch-$os';
  }
}
