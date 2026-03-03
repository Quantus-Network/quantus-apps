import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class RecoveryPhraseScreen extends StatefulWidget {
  const RecoveryPhraseScreen({super.key, this.walletIndex = 0});

  final int walletIndex;

  @override
  State<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
}

class _RecoveryPhraseScreenState extends State<RecoveryPhraseScreen> {
  final _settingsService = SettingsService();
  final _authService = LocalAuthService();
  List<String> _words = [];
  bool _revealed = false;

  Future<void> _toggleReveal() async {
    if (_revealed) {
      setState(() {
        _revealed = false;
      });
      return;
    }

    final ok = await _authService.authenticate(localizedReason: 'Authenticate to reveal recovery phrase');
    if (!ok || !mounted) return;

    setState(() {
      _revealed = true;
    });
  }

  void _loadMnemonic() async {
    final mnemonic = await _settingsService.getMnemonic(widget.walletIndex);
    if (mnemonic != null && mounted) {
      setState(() {
        _words = mnemonic.split(' ');
      });
    }
  }

  void _copyToClipboard() {
    context.copyTextWithToaster(_words.join(' '), message: 'Recovery phrase copied to clipboard');
  }

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Scaffold(
      backgroundColor: colors.background,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBackButton(),
                    Text('Recovery Phrase', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
                    const SizedBox(width: 24),
                  ],
                ),
                const SizedBox(height: 40),
                _warning(colors, text),
                const SizedBox(height: 40),
                Expanded(
                  child: SingleChildScrollView(
                    child: MnemonicGrid(words: _words, isRevealed: _revealed),
                  ),
                ),
                const SizedBox(height: 16),
                IgnorePointer(
                  ignoring: !_revealed,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _revealed ? 1.0 : 0.0,
                    child: _copyRow(colors, text),
                  ),
                ),
                const SizedBox(height: 16),
                _revealButton(colors, text),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _warning(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.accentPink, size: 24),
            const SizedBox(width: 8),
            Text('Important Warning', style: text.smallTitle?.copyWith(color: colors.accentPink)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Your recovery phrase is the only way to restore your wallet. Never share it with anyone. Anyone with your recovery phrase has full access to your funds.',
          style: text.paragraph,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _copyRow(AppColorsV2 colors, AppTextTheme text) {
    return Button.simple(
      padding: const EdgeInsets.all(0),
      label: 'Copy to clipboard',
      onTap: _copyToClipboard,
      variant: ButtonVariant.transparent,
      textStyle: text.smallParagraph?.copyWith(color: colors.textPrimary),
      icon: Icon(Icons.copy, color: colors.textPrimary, size: 14),
    );
  }

  Widget _revealButton(AppColorsV2 colors, AppTextTheme text) {
    final label = _revealed ? 'Hide Recovery Phrase' : 'Reveal Recovery Phrase';
    final icon = _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined;

    return Button.simple(
      label: label,
      onTap: _toggleReveal,
      variant: ButtonVariant.secondary,
      icon: Icon(icon, color: colors.textPrimary, size: 16),
      iconPlacement: IconPlacement.leading,
    );
  }
}
