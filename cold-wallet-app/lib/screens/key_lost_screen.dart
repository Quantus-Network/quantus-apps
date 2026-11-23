import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';
import 'package:quantus_cold_wallet/components/outcome_view.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// A sealed wallet whose phrase iOS destroyed, which it does when Face ID is
/// changed or the passcode turned off. The accounts are still listed; the
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
        'iOS removed the signing key from this iPhone because Face ID was changed or the passcode was turned off. '
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
