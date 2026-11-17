import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_button.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/wave_field.dart';
import 'package:quantus_desktop_wallet/utils/ascii_field.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The first page on a device with no wallet: create one or import one, over
/// the website's moving wave field. Moving the cursor changes the field's
/// wave mode. With the system's reduced motion on, the field stands still.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({
    super.key,
    required this.isCreating,
    required this.error,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  /// Whether a wallet is being created right now.
  final bool isCreating;

  /// Why the last attempt to create a wallet failed, if it did.
  final String? error;
  final VoidCallback onCreateWallet;
  final VoidCallback onImportWallet;

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  /// The mode the website's field starts in.
  (int, int) _waveMode = (2, 2);

  void _onHover(Offset position) {
    final size = context.size!;
    final mode = waveModeAt(position.dx / size.width, position.dy / size.height);
    if (mode != _waveMode) setState(() => _waveMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final isMoving = !MediaQuery.disableAnimationsOf(context);

    return MouseRegion(
      onHover: isMoving ? (event) => _onHover(event.localPosition) : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: WaveField(mode: _waveMode, animate: isMoving),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: WaveFieldScrim())),
          OnboardingPage(
            contentWidth: 720,
            // Not a control: a press on it falls through to the strip behind,
            // which moves the window.
            leading: IgnorePointer(child: Image.asset('assets/quantus_orange_logo.png', height: 16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drawn in capitals, which is a look: a screen reader gets
                // the words as they are written.
                Semantics(
                  label: l10n.desktopWelcomeEyebrow,
                  excludeSemantics: true,
                  child: Text(
                    l10n.desktopWelcomeEyebrow.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: text.dataAddress.copyWith(color: colors.accentFlare, letterSpacing: 2.4, height: 1),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${l10n.desktopWelcomeTitleLine1}\n${l10n.desktopWelcomeTitleLine2}',
                  textAlign: TextAlign.center,
                  style: text.titleHero.copyWith(
                    fontSize: 52,
                    height: 1.02,
                    letterSpacing: -1.3,
                    color: colors.textWhite,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.desktopWelcomeBody,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge.copyWith(color: colors.textContent.useOpacity(0.6), letterSpacing: 0.3),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  children: [
                    OnboardingButton(
                      label: l10n.welcomeCreateNewWallet,
                      onTap: widget.onCreateWallet,
                      isLoading: widget.isCreating,
                    ),
                    OnboardingButton(
                      label: l10n.welcomeImportWallet,
                      onTap: widget.onImportWallet,
                      isSecondary: true,
                      isDisabled: widget.isCreating,
                    ),
                  ],
                ),
                if (widget.error case final error?) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: text.caption.copyWith(color: colors.semanticEmber),
                  ),
                ],
              ],
            ),
          ),
          if (isMoving)
            Positioned(
              right: 24,
              bottom: 24,
              child: IgnorePointer(child: _WaveModeReadout(mode: _waveMode)),
            ),
        ],
      ),
    );
  }
}

/// Names the wave mode the field is moving to, and says how to change it.
class _WaveModeReadout extends ConsumerWidget {
  const _WaveModeReadout({required this.mode});

  final (int, int) mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final flare = context.colorsV3.accentFlare;
    final label = context.themeTextV3.dataAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(l10n.desktopWaveModeLabel, style: label.copyWith(color: flare.useOpacity(0.4), letterSpacing: 1.6)),
        const SizedBox(height: 4),
        Text(
          '${mode.$1},${mode.$2}',
          style: context.themeTextV3.labelData.copyWith(color: flare.useOpacity(0.5), letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        Text(l10n.desktopWaveModeHint, style: label.copyWith(color: flare.useOpacity(0.22), letterSpacing: 1.2)),
      ],
    );
  }
}
