import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';

class ShowRecoveryPhraseScreen extends StatefulWidget {
  const ShowRecoveryPhraseScreen({super.key});

  @override
  State<ShowRecoveryPhraseScreen> createState() =>
      _ShowRecoveryPhraseScreenState();
}

class _ShowRecoveryPhraseScreenState extends State<ShowRecoveryPhraseScreen> {
  bool _isRevealed = false;

  // Mock recovery phrase
  final List<String> _recoveryPhrase = [
    'future',
    'use',
    'crash',
    'bubble',
    'disagree',
    'yard',
    'exit',
    'enact',
    'drum',
    'plank',
    'target',
    'organ',
    'space',
    'large',
    'command',
    'bliss',
    'table',
    'glass',
    'always',
    'stand',
    'screen',
    'cable',
    'vent',
    'height',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const WalletAppBar(title: 'Your Recovery Phrase'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      _buildDescription(),
                      const SizedBox(height: 30),
                      _buildMnemonicGrid(),
                      const SizedBox(height: 30),
                      if (_isRevealed) _buildCopyToClipboard(),
                      const SizedBox(height: 30),
                      _buildWarning(),
                      const SizedBox(height: 80), // Spacer for button
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildDoneButton(context),
    );
  }

  Widget _buildDescription() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keep your Recovery Phrase Safe',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 13),
        Text(
          'This is the only way to recover your wallet. Anyone who has this phrase will have full access to this wallet, your funds may be lost.',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildMnemonicGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MnemonicGrid(words: _recoveryPhrase),
          if (!_isRevealed) _buildRevealOverlay(),
        ],
      ),
    );
  }

  Widget _buildRevealOverlay() {
    return Positioned.fill(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.40),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_off, color: Colors.white, size: 40),
            const SizedBox(height: 17),
            const Text(
              'This Recovery Phrase provides access to this wallet, only reveal if you are in a secure location',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 17),
            ElevatedButton(
              onPressed: () => setState(() => _isRevealed = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.25),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 5,
                ),
              ),
              child: const Text(
                'Reveal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyToClipboard() {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: _recoveryPhrase.join(' '))).then((
          _,
        ) {
          showTopSnackBar(
            context,
            title: "Copied",
            message: "Recovery phrase copied to clipboard.",
            icon: buildCheckmarkIcon(),
          );
        });
      },
      child: Opacity(
        opacity: 0.80,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.copy, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            const Text(
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
    );
  }

  Widget _buildWarning() {
    return const Text(
      'Do not share your Recovery Phrase with any 3rd party, person, website or application',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white60,
        fontSize: 14,
        fontFamily: 'Fira Code',
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(
              color: Color(0xFF0E0E0E),
              fontSize: 18,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildCheckmarkIcon() {
  return Container(
    width: 24,
    height: 24,
    decoration: const ShapeDecoration(
      color: Color(0xFF0CE6ED),
      shape: OvalBorder(),
    ),
    child: const Center(
      child: Icon(Icons.check, color: Colors.black, size: 16),
    ),
  );
}
