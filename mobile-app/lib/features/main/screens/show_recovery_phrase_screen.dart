import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/features/components/reveal_overlay.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

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
      extendBodyBehindAppBar: true,
      backgroundColor: context.themeColors.background,
      appBar: const WalletAppBar(title: 'Your Recovery Phrase'),
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDescription(),
                      const SizedBox(height: 18),
                      _buildMnemonicContainer(),
                      const SizedBox(height: 18),
                      if (_isRevealed) _buildCopyToClipboard(),
                      const SizedBox(height: 30),
                      if (!_isRevealed) _buildWarning(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildDoneButton(),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keep your Recovery Phrase Safe',
            style: context.themeText.smallTitle,
          ),
          const SizedBox(height: 13),
          Text(
            // ignore: lines_longer_than_80_chars
            'This is the only way to recover your wallet. Anyone who has this phrase will have full access to this wallet, your funds may be lost.',
            style: context.themeText.smallParagraph?.copyWith(
              color: context.themeColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicContainer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color.fromARGB(255, 170, 69, 22),
                        Colors.black,
                        Colors.black,
                        Colors.black,
                        Colors.black,
                        Color.fromARGB(255, 33, 66, 136),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: RevealOverlay(
                    onReveal: () => setState(() => _isRevealed = true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyToClipboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: InkWell(
        onTap: () {
          ClipboardExtensions.copyTextWithSnackbar(
            context,
            _recoveryPhrase.join(' '),
            message: 'Recovery phrase copied to clipboard',
          );
          TelemetryService().sendEvent('settings_copy_recovery_phrase');
        },
        child: Opacity(
          opacity: 0.80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.copy,
                color: Colors.white,
                size: context.isTablet ? 28 : 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Copy to Clipboard',
                style: context.themeText.smallParagraph,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarning() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Text(
        // ignore: lines_longer_than_80_chars
        'Do not share your Recovery Phrase with any 3rd party, person, website or application',
        style: context.themeText.smallParagraph?.copyWith(
          color: context.themeColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildDoneButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: context.isTablet ? 18 : 16,
              horizontal: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: Text(
            'Done',
            style: context.themeText.smallTitle?.copyWith(
              color: context.themeColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
