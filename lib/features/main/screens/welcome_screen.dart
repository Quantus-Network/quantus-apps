import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/import_wallet_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 84),

                // Welcome text
                const Text(
                  'Welcome to',
                  style: TextStyle(
                    color: Color(0xFFE6E6E6),
                    fontSize: 20,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 27),

                // Logo
                Container(
                  // width: size.width * 1.0,
                  // height: size.height * 0.20,
                  // decoration: BoxDecoration(
                  //   color: Colors.grey.useOpacity(0.1),
                  //   borderRadius: BorderRadius.circular(12),
                  // ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/RES logo main.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 27),

                // Subtitle
                SizedBox(
                  width: size.width * 0.9,
                  child: const Text(
                    'The Quantum-Secure Network',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE6E6E6),
                      fontSize: 21,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(height: 27),

                // Description
                SizedBox(
                  width: size.width * 0.9,
                  child: const Text(
                    'Create a new wallet or import an existing one to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE6E6E6),
                      fontSize: 16,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const Spacer(),

                // Buttons
                Column(
                  children: [
                    // Create Wallet Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateWalletScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Create a New Wallet',
                          style: TextStyle(
                            color: Color(0xFF0E0E0E),
                            fontSize: 18,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 17),

                    // Import Wallet Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ImportWalletScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          backgroundColor: Colors.black.useOpacity(0.25),
                        ),
                        child: const Text(
                          'Import Your Wallet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
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
