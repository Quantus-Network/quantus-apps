import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';
import 'package:quantus_cold_wallet/components/outcome_view.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/ui/seal_wording.dart';

/// A sealed wallet whose phrase the device destroyed, which it does when the
/// biometrics change or the screen lock is turned off. The accounts are still listed; the
/// recovery phrase puts their key back, and a reset forgets them.
class KeyLostScreen extends ConsumerWidget {
  const KeyLostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutcomeView(
    appBarTitle: 'Signing key removed',
    showBackButton: false,
    glyph: ColdIcons.warning,
    glyphColor: context.colorsV3.semanticSand,
    title: 'Restore your key',
    body:
        'This $deviceName removed the signing key because ${SealPolicy.biometry.credential} changed or the '
        '$screenLockName was turned off. '
        'Your accounts and funds are untouched. Enter your recovery phrase to put the key back.',
    bottom: Column(
      children: [
        QuantusButton.simple(
          label: 'Enter Recovery Phrase',
          padding: coldButtonPadding,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ImportWalletScreen(restoring: ref.read(accountsProvider))),
          ),
        ),
        const SizedBox(height: 12),
        QuantusButton.simple(
          label: 'Reset wallet…',
          variant: ButtonVariant.ghost,
          padding: coldButtonPadding,
          onTap: () => confirmResetWallet(context, ref),
        ),
      ],
    ),
  );
}
