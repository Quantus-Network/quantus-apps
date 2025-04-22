import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/core/services/human_readable_checksum_service.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  ImportWalletScreenState createState() => ImportWalletScreenState();
}

class ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _mnemonicController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _importWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final input = _mnemonicController.text.trim();

      // Check if it's a derivation path
      if (input.startsWith('//')) {
        // No validation needed for derivation paths
        debugPrint('Using derivation path: $input');
      } else {
        // Validate mnemonic
        final words = input.split(' ').where((word) => word.isNotEmpty).toList();
        if (words.length != 12 && words.length != 24) {
          throw Exception('Mnemonic must be 12 or 24 words');
        }
      }

      final walletInfo = await SubstrateService().generateWalletFromSeed(input);
      // Save wallet info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_wallet', true);
      await prefs.setString('mnemonic', input);
      await prefs.setString('account_id', walletInfo.accountId);
      await prefs.setString(
          'wallet_name', await HumanReadableChecksumService().getHumanReadableName(walletInfo.accountId));

      if (context.mounted && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WalletMain()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Wallet'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your 12 or 24 word mnemonic phrase',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mnemonicController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6B46C1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: const Color(0xFF6B46C1).useOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2D2D2D),
                  hintText: 'Enter your mnemonic phrase...',
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Enter all words separated by spaces',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data != null && data.text != null) {
                        _mnemonicController.text = data.text!;
                      }
                    },
                    tooltip: 'Paste',
                  ),
                ],
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const Spacer(),
              SafeArea(
                minimum: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add test button for Alice's wallet
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          _mnemonicController.text = crystalAlice;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Crystal Alice development account loaded')),
                          );
                        },
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Load Test Account (Crystal Alice)'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9F7AEA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _importWallet,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Import Wallet'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
