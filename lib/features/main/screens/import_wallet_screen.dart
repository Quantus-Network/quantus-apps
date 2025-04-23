import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
      await prefs.setString('wallet_name', walletInfo.walletName);

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
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.54,
              child: Image.asset(
                'assets/BG_00 1.png', // Assuming this is the correct background
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 84), // Adjust top padding to match design (128 - 44 for status bar assumption)
                  const Text(
                    'Import Wallet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'Restore an existing wallet with your 12 or 24 word recovery phrase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.useOpacity(0.6), // alpha: 153 -> 0.6
                      fontSize: 14,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                      height: 1.21,
                    ),
                  ),
                  const SizedBox(height: 21),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mnemonicController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black.useOpacity(0.5), // Darker background for field
                            contentPadding: const EdgeInsets.all(13),
                            border: OutlineInputBorder(
                              // Default border (e.g., when error)
                              borderSide: const BorderSide(color: Color(0xFF9F7AEA), width: 1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                width: 1,
                                color: const Color(0xFF9F7AEA).useOpacity(0.8), // Purple border
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF9F7AEA), width: 1.5),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            hintText: 'Type in or paste your recovery phrase. Separate words with spaces',
                            hintStyle: TextStyle(
                              color: Colors.white.useOpacity(0.5), // alpha: 128 -> 0.5
                              fontSize: 13,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          maxLines: null, // Allows unlimited lines
                          minLines: 6, // Set a minimum height (adjust as needed)
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.paste, color: Colors.white70),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: Colors.white70,
                      ),
                      child: CheckboxListTile(
                        title: const Text(
                          'Import Crystal Alice test account',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontFamily: 'Fira Code',
                          ),
                        ),
                        value: _mnemonicController.text == crystalAlice,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _mnemonicController.text = crystalAlice;
                              _errorMessage = '';
                            } else {
                              if (_mnemonicController.text == crystalAlice) {
                                _mnemonicController.clear();
                              }
                            }
                          });
                        },
                        activeColor: const Color(0xFF9F7AEA),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 100),
                  GestureDetector(
                    onTap: _isLoading ? null : _importWallet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(0.50, 0.00),
                          end: Alignment(0.50, 1.00),
                          colors: [Color(0xFF0CE6ED), Color(0xFF8AF9A8)],
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Color(0xFF0E0E0E)),
                              )
                            : const Text(
                                'Import Wallet',
                                style: TextStyle(
                                  color: Color(0xFF0E0E0E),
                                  fontSize: 18,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
