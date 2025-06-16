import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NodeIdentitySetupScreen extends StatefulWidget {
  const NodeIdentitySetupScreen({super.key});

  @override
  State<NodeIdentitySetupScreen> createState() => _NodeIdentitySetupScreenState();
}

class _NodeIdentitySetupScreenState extends State<NodeIdentitySetupScreen> {
  bool _isIdentitySet = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkNodeIdentity();
  }

  Future<String> _getNodeIdentityPath() async {
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    return '$quantusHome/node_key.p2p';
  }

  Future<void> _checkNodeIdentity() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final identityPath = await _getNodeIdentityPath();
      final identityFile = File(identityPath);
      final exists = await identityFile.exists();
      if (mounted) {
        setState(() {
          _isIdentitySet = exists;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking node identity: $e');
      if (mounted) {
        setState(() {
          _isIdentitySet = false;
          _isLoading = false;
        });
      }
    }
  }

  void _setNodeIdentity() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await BinaryManager.ensureNodeKeyFile();
      _checkNodeIdentity();
    } catch (e) {
      print('Error setting node identity (simulation): $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Node Identity Setup'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _isIdentitySet
                ? _buildIdentitySetView()
                : _buildIdentityNotSetView(),
      ),
    );
  }

  Widget _buildIdentitySetView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Node Identity Set!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            context.go('/rewards_address_setup');
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildIdentityNotSetView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('assets/quantus_icon.svg', width: 80, height: 80),
        const SizedBox(height: 16),
        const Text(
          'Node Identity not set.',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'You need to set a node identity to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _setNodeIdentity,
          icon: const Icon(Icons.person_add),
          label: const Text('Set Node Identity'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }
}
