import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_screen.dart';

class CreateWalletCheckPhraseScreen extends StatefulWidget {
  const CreateWalletCheckPhraseScreen({super.key});

  @override
  State<CreateWalletCheckPhraseScreen> createState() => _CreateWalletCheckPhraseScreenState();
}

class _CreateWalletCheckPhraseScreenState extends State<CreateWalletCheckPhraseScreen> {
  String _walletName = 'Grain-Red-Flash-Hyper-Cloud';

  void _regenerateWalletName() {
    // TODO: Implement actual wallet name generation
    setState(() {
      _walletName = 'New-Random-Wallet-Name';
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/BG_00 1.png'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button and title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
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

                const SizedBox(height: 40),

                // Wallet name section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Your Wallet Name',
                      style: TextStyle(
                        color: Color(0xFFE6E6E6),
                        fontSize: 18,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      _walletName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Regenerate button
                    GestureDetector(
                      onTap: _regenerateWalletName,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh, color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Regenerate',
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

                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'An easy way to recognise your wallets\nRefresh to autogenerate a new name',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 14,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Continue button
                Container(
                  width: 343,
                  padding: const EdgeInsets.all(16),
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(0.50, 0.00),
                      end: Alignment(0.50, 1.00),
                      colors: [Color(0xFF0CE6ED), Color(0xFF8AF9A8)],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateWalletScreen()),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            color: Color(0xFF0E0E0E),
                            fontSize: 18,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 34),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
