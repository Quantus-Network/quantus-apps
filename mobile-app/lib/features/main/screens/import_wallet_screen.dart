import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_mobile_wallet/features/components/gradient_action_button.dart';
import 'package:quantus_mobile_wallet/features/main/screens/navbar.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  ImportWalletScreenState createState() => ImportWalletScreenState();
}

class ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _mnemonicController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  final SettingsService _settingsService = SettingsService();

  Future<void> _importWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final mnemonic = _mnemonicController.text.trim();

      // Check if it's a derivation path
      if (mnemonic.startsWith('//')) {
        // No validation needed for derivation paths
        debugPrint('Using derivation path: $mnemonic');
      } else {
        // Validate mnemonic
        final words = mnemonic
            .split(' ')
            .where((word) => word.isNotEmpty)
            .toList();
        if (words.length != 12 && words.length != 24) {
          throw Exception('Mnemonic must be 12 or 24 words');
        }
      }

      print('discovering OG key! DEBUG.');
      final key = HdWalletService().keyPairAtIndex(mnemonic, -1);
      await _settingsService.setMnemonic(mnemonic);
      await _settingsService.addAccount(
        Account(index: 0, name: 'Account 1', accountId: key.ss58Address),
      );

      if (context.mounted && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Navbar()),
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
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/light_leak_effect_background.jpg',
            ), // Assuming this is the correct background
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Stretch children horizontally
              children: [
                // Back button row remains at the top
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Content previously inside Center/nested Column
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
                  'Restore an existing wallet with your 12 or 24 word '
                  'recovery phrase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.useOpacity(0.6),
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
                          fillColor: Colors.black.useOpacity(0.5),
                          contentPadding: const EdgeInsets.all(13),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFF9F7AEA),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 1,
                              color: const Color(0xFF9F7AEA).useOpacity(0.8),
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFF9F7AEA),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          hintText:
                              'Type in or paste your recovery phrase. Separate'
                              ' words with spaces',
                          hintStyle: TextStyle(
                            color: Colors.white.useOpacity(0.5),
                            fontSize: 13,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        maxLines: null,
                        minLines: 6,
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
                // Padding(
                //   padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                //   child: Theme(
                //     data: Theme.of(context).copyWith(
                //       unselectedWidgetColor: Colors.white70,
                //     ),
                //     // child: CheckboxListTile(
                //     //   title: const Text(
                //     //     'Import Crystal Alice test account',
                //     //     style: TextStyle(
                //     //       color: Colors.white70,
                //     //       fontSize: 13,
                //     //       fontFamily: 'Fira Code',
                //     //     ),
                //     //   ),
                //     //   value: _mnemonicController.text == crystalAlice,
                //     //   onChanged: (bool? value) {
                //     //     setState(() {
                //     //       if (value == true) {
                //     //         _mnemonicController.text = crystalAlice;
                //     //         _errorMessage = '';
                //     //       } else {
                //     //         if (_mnemonicController.text == crystalAlice) {
                //     //           _mnemonicController.clear();
                //     //         }
                //     //       }
                //     //     });
                //     //   },
                //     //   activeColor: const Color(0xFF9F7AEA),
                //     //   controlAffinity: ListTileControlAffinity.leading,
                //     //   contentPadding: EdgeInsets.zero,
                //     //   dense: true,
                //     // ),
                //   ),
                // ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8.0,
                      bottom: 8.0,
                    ), // Added bottom padding
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Spacer(), // Add Spacer to push the button down
                GradientActionButton(
                  label: 'Import Wallet',
                  onPressed: _importWallet,
                  isLoading: _isLoading,
                ),
                const SizedBox(
                  height: 24,
                ), // Consistent bottom padding like CreateWalletScreen
              ],
            ),
          ),
        ),
      ),
    );
  }
}
