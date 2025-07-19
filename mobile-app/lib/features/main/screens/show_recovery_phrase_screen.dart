import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/features/components/reveal_overlay.dart';
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
  List<String> _recoveryPhrase = [];
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    final mnemonic = await _settingsService.getMnemonic();
    if (mnemonic != null) {
      setState(() {
        _recoveryPhrase = mnemonic.split(' ');
      });
    }
  }

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
                      _buildMnemonicContainer(),
                      const SizedBox(height: 30),
                      if (_isRevealed) _buildCopyToClipboard(),
                      // const SizedBox(height: 30),
                      // _buildWarning(),
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
          'This is the only way to recover your wallet.'
          ' Do not share with anyone.',
          // Anyone who has this phrase will have full access to this wallet,
          // your funds may be lost.',
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

  Widget _buildMnemonicContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.useOpacity(0.70),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MnemonicGrid(words: _recoveryPhrase),
          if (!_isRevealed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.useOpacity(0.9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: RevealOverlay(
                  onReveal: () => setState(() => _isRevealed = true),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCopyToClipboard() {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: _recoveryPhrase.join(' ')));
        if (!context.mounted) return;
        showTopSnackBar(
          // ignore: use_build_context_synchronously
          context,
          title: 'Copied',
          message: 'Recovery phrase copied to clipboard.',
          icon: buildCheckmarkIcon(),
        );
      },
      child: const Opacity(
        opacity: 0.80,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.copy, color: Colors.white, size: 24),
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
    );
  }

  // Widget _buildWarning() {
  //   return const Text(
  //     'Do not share your Recovery Phrase with any 3rd party, person, website
  //or application',
  //     textAlign: TextAlign.center,
  //     style: TextStyle(
  //       color: Colors.white60,
  //       fontSize: 14,
  //       fontFamily: 'Fira Code',
  //       fontWeight: FontWeight.w400,
  //     ),
  //   );
  // }

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
