import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_button.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_text.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// Announces a wallet that was just created, and the two accounts it starts
/// with: [account] and the encrypted account beside it. As in the boot intro,
/// a terminal reports each one, a line at a time; Go to Wallet works from the
/// start, so nobody has to wait for the lines.
class WalletCreatedPage extends ConsumerStatefulWidget {
  const WalletCreatedPage({super.key, required this.account, required this.onGoToWallet});

  final Account account;
  final VoidCallback onGoToWallet;

  /// The terminal line at [index], from the top.
  static Key lineKey(int index) => ValueKey('wallet-created-line-$index');

  @override
  ConsumerState<WalletCreatedPage> createState() => _WalletCreatedPageState();
}

class _WalletCreatedPageState extends ConsumerState<WalletCreatedPage> with SingleTickerProviderStateMixin {
  /// The boot intro's pace.
  static const int _lineEveryMs = 120;
  static const int _lineCount = 3;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: (_lineCount - 1) * _lineEveryMs),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final isInstant = MediaQuery.disableAnimationsOf(context);
    final lines = [l10n.accountReadyWalletCreated, widget.account.name, l10n.createAccountEncryptedDefaultName];
    assert(lines.length == _lineCount);

    return OnboardingPage(
      contentWidth: 520,
      // Not a control: a press on it falls through to the strip behind,
      // which moves the window.
      leading: IgnorePointer(child: Image.asset('assets/quantus_orange_logo.png', height: 16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final elapsedMs = _clock.value * _clock.duration!.inMilliseconds;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, name) in lines.indexed)
                    _TerminalLine(
                      opacityKey: WalletCreatedPage.lineKey(index),
                      name: name,
                      status: l10n.desktopBootStatusOk,
                      isShown: isInstant || elapsedMs >= index * _lineEveryMs,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          OnboardingHeadline(l10n.desktopWalletReadyHeadline),
          const SizedBox(height: 14),
          OnboardingLede(l10n.desktopWalletReadyBody(widget.account.name, l10n.createAccountEncryptedDefaultName)),
          const SizedBox(height: 32),
          OnboardingButton(label: l10n.accountReadyGoToWallet, onTap: widget.onGoToWallet),
        ],
      ),
    );
  }
}

/// One line of the terminal: `> NAME ....... [OK]`. Drawn in capitals, which
/// is a look: a screen reader gets the name as it is written.
class _TerminalLine extends StatelessWidget {
  const _TerminalLine({required this.opacityKey, required this.name, required this.status, required this.isShown});

  /// Marks the part that fades in, so the line's progress can be found.
  final Key opacityKey;
  final String name;
  final String status;
  final bool isShown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final style = context.themeTextV3.dataAddressLarge.copyWith(height: 1, letterSpacing: 0.6, color: colors.textMuted);

    return Semantics(
      label: '$name $status',
      excludeSemantics: true,
      child: Opacity(
        key: opacityKey,
        opacity: isShown ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Text('> ${name.toUpperCase()}', style: style),
              const SizedBox(width: 8),
              // Dot leaders up to the status, as many as fit.
              Expanded(
                child: Text(
                  '.' * 200,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: style.copyWith(color: colors.textMuted2.useOpacity(0.5)),
                ),
              ),
              const SizedBox(width: 8),
              Text(status, style: style.copyWith(color: colors.semanticSage)),
            ],
          ),
        ),
      ),
    );
  }
}
