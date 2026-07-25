import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_caution_scaffold.dart';

class RecoveryPhraseConfirmationScreen extends ConsumerStatefulWidget {
  const RecoveryPhraseConfirmationScreen({super.key, required this.walletIndex, this.showAlreadyBackedUp = false});

  final int walletIndex;

  /// When true (the home backup nudge), offers an "I already backed up" action
  /// that dismisses the nudge without revealing the phrase.
  final bool showAlreadyBackedUp;

  @override
  ConsumerState<RecoveryPhraseConfirmationScreen> createState() => _RecoveryPhraseConfirmationScreenState();
}

class _RecoveryPhraseConfirmationScreenState extends ConsumerState<RecoveryPhraseConfirmationScreen> {
  Future<void> _onContinue() async {
    final l10n = ref.read(l10nProvider);
    final authed = await LocalAuthService().authenticate(localizedReason: l10n.settingsRecoveryConfirmAuthReason);

    if (authed && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => RecoveryPhraseScreen(walletIndex: widget.walletIndex)));
    } else {
      if (mounted) {
        context.showErrorToaster(message: l10n.settingsRecoveryConfirmAuthRequired);
      }
    }
  }

  void _onAlreadyBackedUp() {
    ref.read(settingsServiceProvider).setRecoveryPhraseViewed(widget.walletIndex);
    ref.invalidate(recoveryPhraseViewedProvider(widget.walletIndex));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return KeyedSubtree(
      key: const Key(E2EKeys.recoveryPhraseConfirmScreen),
      child: SettingsCautionScaffold(
        appBarTitle: l10n.settingsRecoveryPhraseTitle,
        data: SettingsCautionScaffoldData.recoveryPhrase(l10n),
        continueLabel: l10n.commonContinue,
        continueButtonKey: const Key(E2EKeys.recoveryPhraseConfirmContinueButton),
        onContinue: _onContinue,
        secondaryLabel: widget.showAlreadyBackedUp ? l10n.settingsRecoveryAlreadyBackedUp : null,
        onSecondary: widget.showAlreadyBackedUp ? _onAlreadyBackedUp : null,
      ),
    );
  }
}
