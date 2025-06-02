import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';

class NodeSetupScreen extends StatefulWidget {
  const NodeSetupScreen({Key? key}) : super(key: key);

  @override
  _NodeSetupScreenState createState() => _NodeSetupScreenState();
}

class _NodeSetupScreenState extends State<NodeSetupScreen> {
  bool _isNodeInstalled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkNodeInstallation();
  }

  Future<void> _checkNodeInstallation() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Only check if the binary file exists, do not trigger download.
      final String binaryPath = await BinaryManager.getNodeBinaryFilePath();
      final bool installed = await File(binaryPath).exists();
      setState(() {
        _isNodeInstalled = installed;
        _isLoading = false;
      });
    } catch (e) {
      // If an error occurs, assume not installed or check failed.
      print('Error checking node binary: $e');
      setState(() {
        _isNodeInstalled = false;
        _isLoading = false;
      });
      // TODO: Potentially show a user-friendly error message here
    }
  }

  void _installNode() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Trigger the installation/download process via BinaryManager
      await BinaryManager.ensureNodeBinary();
      // If successful, update installation status
      // We directly set _isNodeInstalled to true here, assuming ensureNodeBinary succeeds.
      // And then refresh the state by calling _checkNodeInstallation to be sure.
      setState(() {
        _isNodeInstalled = true;
      });
      // To be absolutely sure and refresh UI correctly, re-check.
      // This might be slightly redundant if ensureNodeBinary is guaranteed to throw on failure,
      // but ensures the UI reflects the true state.
      await _checkNodeInstallation();
    } catch (e) {
      print('Error during node installation: $e');
      setState(() {
        _isLoading = false;
      });
      // TODO: Show a user-friendly error message indicating installation failed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Node Setup'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _isNodeInstalled
                ? _buildNodeInstalledView()
                : _buildNodeNotInstalledView(),
      ),
    );
  }

  Widget _buildNodeInstalledView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Node Installed!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

  Widget _buildNodeNotInstalledView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('assets/quantus_icon.svg', width: 80, height: 80),
        const SizedBox(height: 16),
        const Text(
          'Node not found.',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'You need to install the node to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _installNode,
          icon: const Icon(Icons.download),
          label: const Text('Install Node'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }
}
