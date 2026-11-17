import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
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
                    Opacity(
                      key: WalletCreatedPage.lineKey(index),
                      opacity: isInstant || elapsedMs >= index * _lineEveryMs ? 1 : 0,
                      child: TerminalLine(name: name, status: l10n.desktopBootStatusOk),
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
