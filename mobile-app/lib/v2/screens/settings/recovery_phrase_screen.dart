import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
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
        _words = [];
      });
      return;
    }
    if (_authService.isLocalAuthEnabled()) {
      final ok = await _authService.authenticate(
        localizedReason: 'Authenticate to reveal recovery phrase',
        biometricOnly: false,
      );
      if (!ok || !mounted) return;
    }
    final mnemonic = await _settingsService.getMnemonic(widget.walletIndex);
    if (mnemonic != null && mounted) {
      setState(() {
        _words = mnemonic.split(' ');
        _revealed = true;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _words.join(' ')));
    showCopySnackbar(context, title: 'Copied!', message: 'Recovery phrase copied to clipboard');
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
                Expanded(child: SingleChildScrollView(child: _wordGrid(colors, text))),
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
          style: text.smallParagraph?.copyWith(color: colors.textSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _wordGrid(AppColorsV2 colors, AppTextTheme text) {
    final count = _revealed ? _words.length : 24;
    final rows = <Widget>[];
    for (var i = 0; i < count; i += 3) {
      final chips = <Widget>[];
      for (var j = i; j < i + 3 && j < count; j++) {
        final word = _revealed ? _words[j] : 'blurred';
        chips.add(Expanded(child: _wordChip(j + 1, word, colors, text)));
        if (j < i + 2 && j < count - 1) chips.add(const SizedBox(width: 9));
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 9));
      rows.add(Row(children: chips));
    }
    return Column(children: rows);
  }

  Widget _wordChip(int index, String word, AppColorsV2 colors, AppTextTheme text) {
    final wordWidget = Text(
      word,
      textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false),
      style: text.detail?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
      overflow: TextOverflow.ellipsis,
    );

    return SizedBox(
      child: GlassContainer(
        asset: GlassContainer.mediumSmallAsset,
        filled: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 8),
            Text('$index', style: text.detail?.copyWith(color: colors.textSecondary)),
            const SizedBox(width: 6),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 50),
                    opacity: _revealed ? 1.0 : 0.0,
                    child: wordWidget,
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 50),
                    opacity: _revealed ? 0.0 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: wordWidget),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyRow(AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: _copyToClipboard,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Copy to clipboard', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
          const SizedBox(width: 8),
          Icon(Icons.copy, color: colors.textPrimary, size: 14),
        ],
      ),
    );
  }

  Widget _revealButton(AppColorsV2 colors, AppTextTheme text) {
    return GlassContainer(
      asset: GlassContainer.wideAsset,
      onTap: _toggleReveal,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: colors.textPrimary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _revealed ? 'Hide Recovery Phrase' : 'Reveal Recovery Phrase',
              style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
