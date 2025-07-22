import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';

class NodeSetupScreen extends StatefulWidget {
  const NodeSetupScreen({super.key});

  @override
  State<NodeSetupScreen> createState() => _NodeSetupScreenState();
}

class _NodeSetupScreenState extends State<NodeSetupScreen> {
  bool _isNodeInstalled = false;
  bool _isExternalMinerInstalled = false;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadProgressText = "";
  String _currentDownloadingBinary = "";

  @override
  void initState() {
    super.initState();
    _checkBinariesInstallation();
  }

  Future<void> _checkBinariesInstallation() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Check both binaries
      final String nodeBinaryPath = await BinaryManager.getNodeBinaryFilePath();
      final bool nodeInstalled = await File(nodeBinaryPath).exists();

      final String minerBinaryPath =
          await BinaryManager.getExternalMinerBinaryFilePath();
      final bool minerInstalled = await File(minerBinaryPath).exists();

      setState(() {
        _isNodeInstalled = nodeInstalled;
        _isExternalMinerInstalled = minerInstalled;
        _isLoading = false;
      });
    } catch (e) {
      // If an error occurs, assume not installed or check failed.
      print('Error checking binaries: $e');
      setState(() {
        _isNodeInstalled = false;
        _isExternalMinerInstalled = false;
        _isLoading = false;
      });
    }
  }

  void _installBinaries() async {
    setState(() {
      _isLoading = true;
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadProgressText = "Starting downloads...";
    });

    try {
      // Install node binary first
      if (!_isNodeInstalled) {
        setState(() {
          _currentDownloadingBinary = "Node Binary";
          _downloadProgressText = "Downloading Node Binary...";
        });

        await BinaryManager.ensureNodeBinary(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                if (progress.totalBytes > 0) {
                  _downloadProgress =
                      progress.downloadedBytes / progress.totalBytes;
                  _downloadProgressText =
                      "Node: ${(progress.downloadedBytes / (1024 * 1024)).toStringAsFixed(2)} MB / ${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
                } else {
                  _downloadProgress = progress.downloadedBytes > 0 ? 1.0 : 0.0;
                  _downloadProgressText = progress.downloadedBytes > 0
                      ? "Node Downloaded"
                      : "Downloading Node...";
                }
              });
            }
          },
        );

        setState(() {
          _isNodeInstalled = true;
        });
      }

      // Install external miner binary
      if (!_isExternalMinerInstalled) {
        setState(() {
          _currentDownloadingBinary = "External Miner";
          _downloadProgress = 0.0;
          _downloadProgressText = "Downloading External Miner...";
        });

        await BinaryManager.ensureExternalMinerBinary(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                if (progress.totalBytes > 0) {
                  _downloadProgress =
                      progress.downloadedBytes / progress.totalBytes;
                  _downloadProgressText =
                      "Miner: ${(progress.downloadedBytes / (1024 * 1024)).toStringAsFixed(2)} MB / ${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
                } else {
                  _downloadProgress = progress.downloadedBytes > 0 ? 1.0 : 0.0;
                  _downloadProgressText = progress.downloadedBytes > 0
                      ? "Miner Downloaded"
                      : "Downloading Miner...";
                }
              });
            }
          },
        );

        setState(() {
          _isExternalMinerInstalled = true;
        });
      }

      // Both binaries installed successfully
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgressText = "All binaries installed successfully!";
        });
      }

      // Re-check to ensure everything is properly set
      await _checkBinariesInstallation();
    } catch (e) {
      print('Error during binaries installation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDownloading = false;
          _downloadProgressText = "Error: ${e.toString()}";
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error installing binaries: ${e.toString()}')),
        );
      }
    }
  }

  bool get _allBinariesInstalled =>
      _isNodeInstalled && _isExternalMinerInstalled;

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_isDownloading) {
      bodyContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Installing Mining Software...',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _currentDownloadingBinary,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Text(_downloadProgressText),
        ],
      );
    } else if (_isLoading) {
      bodyContent = const CircularProgressIndicator();
    } else if (_allBinariesInstalled) {
      bodyContent = _buildBinariesInstalledView();
    } else {
      bodyContent = _buildBinariesNotInstalledView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mining Software Setup')),
      body: Center(child: bodyContent),
    );
  }

  Widget _buildBinariesInstalledView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Mining Software Installed!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text('Node Binary'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text('External Miner'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // Navigate to the next setup step (Set Node Identity)
            context.go('/node_identity_setup');
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildBinariesNotInstalledView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('assets/quantus_icon.svg', width: 80, height: 80),
        const SizedBox(height: 16),
        const Text(
          'Mining software not found.',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'You need to install the node and external miner to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        // Show status of each binary
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isNodeInstalled ? Icons.check : Icons.close,
                  color: _isNodeInstalled ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Node Binary'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isExternalMinerInstalled ? Icons.check : Icons.close,
                  color: _isExternalMinerInstalled ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('External Miner'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _installBinaries,
          icon: const Icon(Icons.download),
          label: Text(
            _allBinariesInstalled ? 'All Installed' : 'Install Mining Software',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }
}
