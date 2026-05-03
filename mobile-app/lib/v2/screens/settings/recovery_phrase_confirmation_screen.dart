import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_caution_scaffold.dart';

class RecoveryPhraseConfirmationScreen extends StatefulWidget {
  const RecoveryPhraseConfirmationScreen({super.key, required this.walletIndex});

  final int walletIndex;

  @override
  State<RecoveryPhraseConfirmationScreen> createState() => _RecoveryPhraseConfirmationScreenState();
}

class _RecoveryPhraseConfirmationScreenState extends State<RecoveryPhraseConfirmationScreen> {
  bool _acknowledged = false;

  Future<void> _onContinue() async {
    final authed = await LocalAuthService().authenticate(localizedReason: 'Authenticate to see recovery phrase');

    if (authed && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => RecoveryPhraseScreen(walletIndex: widget.walletIndex)));
    } else {
      if (mounted) {
        context.showErrorToaster(message: 'Authentication required to see recovery phrase');
      }

      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = const SettingsCautionScaffoldData.recoveryPhrase();

    return SettingsCautionScaffold(
      appBarTitle: 'Recovery Phrase',
      data: data,
      checkboxChecked: _acknowledged,
      onCheckboxChanged: () => setState(() => _acknowledged = !_acknowledged),
      onContinue: _onContinue,
    );
  }
}
