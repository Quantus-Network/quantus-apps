import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/create/new_wallet_recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_caution_scaffold.dart';

class WalletReadyScreenV2 extends ConsumerStatefulWidget {
  const WalletReadyScreenV2({super.key});

  @override
  ConsumerState<WalletReadyScreenV2> createState() => _WalletReadyScreenV2State();
}

class _WalletReadyScreenV2State extends ConsumerState<WalletReadyScreenV2> {
  bool _acknowledged = false;

  void _continue() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NewWalletRecoveryPhraseScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final data = SettingsCautionScaffoldData(
      headline: l10n.createWalletCautionHeadline,
      bulletItems: [l10n.createWalletCautionBullet1, l10n.createWalletCautionBullet2, l10n.createWalletCautionBullet3],
      checkboxLabel: l10n.createWalletCautionCheckboxLabel,
    );

    return SettingsCautionScaffold(
      appBarTitle: l10n.createWalletAppBarTitle,
      data: data,
      continueLabel: l10n.commonContinue,
      checkboxChecked: _acknowledged,
      onCheckboxChanged: () => setState(() => _acknowledged = !_acknowledged),
      onContinue: _continue,
    );
  }
}
