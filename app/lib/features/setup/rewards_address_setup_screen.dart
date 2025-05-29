import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:go_router/go_router.dart'; // Import go_router
import 'package:quantus_sdk/quantus_sdk.dart'; // Assuming quantus_sdk has wallet/address functions
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Will need this for secure storage

enum RewardsAddressSetupStep {
  checking,
  notSet,
  createOrImport,
  createNew,
  importExisting,
  set,
}

class RewardsAddressSetupScreen extends StatefulWidget {
  const RewardsAddressSetupScreen({Key? key}) : super(key: key);

  @override
  _RewardsAddressSetupScreenState createState() => _RewardsAddressSetupScreenState();
}

class _RewardsAddressSetupScreenState extends State<RewardsAddressSetupScreen> {
  RewardsAddressSetupStep _currentStep = RewardsAddressSetupStep.checking;
  String _generatedMnemonic = '';
  final TextEditingController _importController = TextEditingController();

  final _storage = const FlutterSecureStorage(); // For secure storage

  @override
  void initState() {
    super.initState();
    _checkRewardsAddress();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _checkRewardsAddress() async {
    // This will involve checking if an address is stored securely.
    final mnemonic = await _storage.read(key: 'rewards_address_mnemonic'); // Read mnemonic

    setState(() {
      if (mnemonic != null) {
        _currentStep = RewardsAddressSetupStep.set;
        print('Rewards address found in secure storage.');
      } else {
        _currentStep = RewardsAddressSetupStep.notSet;
        print('No rewards address found in secure storage.');
      }
    });
  }

  void _showCreateOrImportOptions() {
    setState(() {
      _currentStep = RewardsAddressSetupStep.createOrImport;
    });
  }

  void _showCreateNewAddress() async {
    setState(() {
      _currentStep = RewardsAddressSetupStep.createNew;
      _generatedMnemonic = 'Generating mnemonic...'; // Placeholder
    });

    try {
      final newMnemonic = await SubstrateService().generateMnemonic();

      setState(() {
        _generatedMnemonic = newMnemonic;
      });

      // Derive seed from mnemonic and securely store it
      await _securelyStoreMnemonic(newMnemonic);

      print('Seed securely stored.');
    } catch (e) {
      // TODO: Handle error (e.g., show a Snackbar)
      print('Error generating mnemonic or storing seed: $e');
      setState(() {
        _currentStep = RewardsAddressSetupStep.notSet; // Go back to not set on error
      });
    }
  }

  void _showImportExistingAddress() {
    setState(() {
      _currentStep = RewardsAddressSetupStep.importExisting;
    });
  }

  void _importAddress() async {
    final mnemonic = _importController.text.trim();
    if (mnemonic.isEmpty) {
      // TODO: Show an error to the user (e.g., Snackbar)
      print('Mnemonic/seed phrase cannot be empty.');
      return;
    }

    print('Attempting to import address with mnemonic: $mnemonic');
    setState(() {
      _currentStep = RewardsAddressSetupStep.checking; // Simulate processing
    });

    try {
      // Derive seed from mnemonic and securely store it
      SubstrateService().dilithiumKeypairFromMnemonic(mnemonic); // Validate mnemonic by trying to derive keypair
      await _securelyStoreMnemonic(mnemonic);

      setState(() {
        _currentStep = RewardsAddressSetupStep.set; // Simulate success
      });
    } catch (e) {
      // TODO: Handle error (e.g., show a Snackbar indicating invalid mnemonic)
      print('Error importing mnemonic or storing seed: $e');
      setState(() {
        _currentStep = RewardsAddressSetupStep.importExisting; // Stay on import screen on error
      });
    }
  }

  Future<void> _securelyStoreMnemonic(String mnemonic) async {
    try {
      await _storage.write(key: 'rewards_address_mnemonic', value: mnemonic);
      print('Mnemonic securely stored.');
    } catch (e) {
      // TODO: Handle error (e.g., show a Snackbar)
      print('Error securely storing seed: $e');
      // Depending on the severity and platform, you might want to show a critical error message.
      throw e; // Rethrow to be caught by the calling function
    }
  }

  void _onAddressSet() {
    // Navigate to the main mining screen
    print('Rewards Address set. Proceed to main screen.');
    context.go('/miner_dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards Address Setup'),
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case RewardsAddressSetupStep.checking:
        return const CircularProgressIndicator();
      case RewardsAddressSetupStep.notSet:
        return _buildNotSetView();
      case RewardsAddressSetupStep.createOrImport:
        return _buildCreateOrImportView();
      case RewardsAddressSetupStep.createNew:
        return _buildCreateNewView();
      case RewardsAddressSetupStep.importExisting:
        return _buildImportExistingView();
      case RewardsAddressSetupStep.set:
        return _buildAddressSetView();
    }
  }

  Widget _buildNotSetView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.account_balance_wallet_outlined, color: Colors.orange, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Rewards Address not set.',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'You need to set a rewards address to receive mining rewards.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _showCreateOrImportOptions,
          icon: const Icon(Icons.wallet_giftcard),
          label: const Text('Set Rewards Address'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateOrImportView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'How would you like to set your rewards address?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _showCreateNewAddress,
          icon: const Icon(Icons.add_card),
          label: const Text('Create New Address'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showImportExistingAddress,
          icon: const Icon(Icons.download),
          label: const Text('Import Existing Address'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateNewView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your New Rewards Address Mnemonic:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850], // Dark background for the mnemonic
              border: Border.all(color: Colors.grey[700]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _generatedMnemonic,
              style: const TextStyle(fontSize: 18, color: Colors.white), // Light text color
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generatedMnemonic));
              // TODO: Show a confirmation message (e.g., Snackbar)
              print('Mnemonic copied to clipboard');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Please write down these 24 words and keep them in a safe place. You will need them to recover your wallet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _onAddressSet, // Navigate to main screen
            child: const Text('I have securely stored my mnemonic'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportExistingView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter your 24-word mnemonic or seed phrase:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _importController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter mnemonic or seed phrase',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _importAddress,
            icon: const Icon(Icons.wallet),
            label: const Text('Import Address'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSetView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.account_balance_wallet, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Rewards Address Set!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _onAddressSet, // Navigate to main screen
          child: const Text('Continue to Miner'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }
}
