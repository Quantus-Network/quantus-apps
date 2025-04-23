import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class ManualBackupScreen extends StatefulWidget {
  final String? initialMnemonic;

  const ManualBackupScreen({super.key, this.initialMnemonic});

  @override
  ManualBackupScreenState createState() => ManualBackupScreenState();
}

class ManualBackupScreenState extends State<ManualBackupScreen> {
  String _mnemonic = '';
  bool _isLoading = false;
  bool _hasSavedMnemonic = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMnemonic != null && widget.initialMnemonic!.isNotEmpty) {
      setState(() {
        _mnemonic = widget.initialMnemonic!;
        _isLoading = false;
      });
    } else {
      _generateMnemonic();
    }
  }

  Future<void> _generateMnemonic() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _mnemonic = await SubstrateService().generateMnemonic();
      final walletInfo = await SubstrateService().generateWalletFromSeed(_mnemonic);
      debugPrint('Generated wallet address: ${walletInfo.accountId}');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error generating mnemonic: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWalletAndContinue() async {
    try {
      final walletInfo = await SubstrateService().generateWalletFromSeed(_mnemonic);

      // Save wallet info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_wallet', true);
      await prefs.setString('mnemonic', _mnemonic);
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
      debugPrint('Error saving wallet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving wallet: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Split the mnemonic string into a list of words
    final words = _mnemonic.isNotEmpty ? _mnemonic.split(' ') : [];

    // Determine button state
    final bool canContinue = _hasSavedMnemonic && !_isLoading;

    return Scaffold(
      // Use the background color from the design
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        // Apply the background image, assuming 'assets/BG_00 1.png' is correct
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/BG_00 1.png'), // Use asset image
            fit: BoxFit.cover,
            opacity: 0.54, // Opacity from the design
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Custom App Bar Row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      // Go back to the previous screen (Check Phrase Screen)
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Create Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40), // Adjust spacing as needed

                // Main content area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title and Description
                        const Text(
                          'Your Secret Recovery Phrase',
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
                          'Write down and save your seed phrase in a secure location. This is the only way to recover your wallet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.useOpacity(153 / 255.0), // Alpha 153
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                            height: 1.21, // Line height
                          ),
                        ),
                        const SizedBox(height: 21),

                        // Mnemonic Phrase Box
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 50.0),
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        else
                          Container(
                            width: double.infinity, // Stretch to padding
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 9), // Adjusted padding
                            decoration: ShapeDecoration(
                              // color: Colors.black.useOpacity(178 / 255.0), // Alpha 178
                              color: Colors.black.useOpacity(0.7), // Adjusted for better visibility
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.start,
                              spacing: 9.0, // Horizontal spacing
                              runSpacing: 10.0, // Vertical spacing
                              children: List.generate(words.length, (index) {
                                return _buildMnemonicWord(index + 1, words[index]);
                              }),
                            ),
                          ),
                        const SizedBox(height: 21),

                        // Copy Button
                        if (!_isLoading)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _mnemonic));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Recovery phrase copied to clipboard')),
                              );
                            },
                            child: const Opacity(
                              opacity: 0.8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy, color: Colors.white, size: 24), // Use actual icon
                                  SizedBox(width: 8),
                                  Text(
                                    'Copy to Clipboard',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20), // Add space before checkbox
                      ],
                    ),
                  ),
                ),

                // Bottom Section (Checkbox and Continue Button)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0), // Padding below button
                  child: Column(
                    children: [
                      // Checkbox Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24, // Keep size consistent
                            height: 24,
                            child: Checkbox(
                              value: _hasSavedMnemonic,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _hasSavedMnemonic = value ?? false;
                                      });
                                    },
                              // Custom styling for checked state
                              activeColor: const Color(0xFF8AF9A8), // Green background when checked
                              checkColor: const Color(0xFF8AF9A8),
                              side: WidgetStateBorderSide.resolveWith((states) {
                                return const BorderSide(width: 1, color: Colors.white);
                              }),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2),
                              ),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'I have copied and stored my seed phrase',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17), // Spacing from design

                      // Continue Button
                      SizedBox(
                        width: double.infinity, // Stretch button
                        child: ElevatedButton(
                          // Use the condition determined earlier
                          onPressed: canContinue ? _saveWalletAndContinue : null,
                          style: ElevatedButton.styleFrom(
                            // Disabled color slightly transparent white
                            disabledBackgroundColor: Colors.white.useOpacity(61 / 255.0),
                            backgroundColor: const Color(0xFF0CE6ED), // Primary color for enabled
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            // Use gradient if needed, but solid color is simpler
                            // foregroundColor: const Color(0xFF0E0E0E), // Text color
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              color: Color(0xFF0E0E0E),
                              fontSize: 18,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to build each mnemonic word container
  Widget _buildMnemonicWord(int index, String word) {
    return Container(
      // Calculate width dynamically or use a fixed suitable width
      // width: 105, // Avoid fixed widths if possible
      constraints: const BoxConstraints(minWidth: 100), // Ensure minimum width
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            // color: Colors.white.useOpacity(38 / 255.0), // Alpha 38
            color: Colors.white.useOpacity(0.15), // Adjusted
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        '$index. $word',
        textAlign: TextAlign.center, // Center text within the box
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontFamily: 'Fira Code',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
