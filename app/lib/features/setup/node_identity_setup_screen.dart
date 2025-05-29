import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NodeIdentitySetupScreen extends StatefulWidget {
  const NodeIdentitySetupScreen({Key? key}) : super(key: key);

  @override
  _NodeIdentitySetupScreenState createState() => _NodeIdentitySetupScreenState();
}

class _NodeIdentitySetupScreenState extends State<NodeIdentitySetupScreen> {
  bool _isIdentitySet = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkNodeIdentity();
  }

  Future<void> _checkNodeIdentity() async {
    // TODO: Implement actual node identity check logic
    // This will likely involve interacting with the running node via quantus_sdk.
    await Future.delayed(const Duration(seconds: 2)); // Placeholder delay

    setState(() {
      // _isIdentitySet = result of the check;
      _isIdentitySet = false; // Simulate identity not set initially
      _isLoading = false;
    });
  }

  void _setNodeIdentity() {
    // TODO: Implement node identity setting logic
    // This will involve sending a command to the node via quantus_sdk.
    print('Set Node Identity button pressed');
    // For now, let's just simulate setting success after a delay
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isIdentitySet = true; // Simulate success
        _isLoading = false;
      });
    });
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
        const Icon(Icons.person_search, color: Colors.orange, size: 80),
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
